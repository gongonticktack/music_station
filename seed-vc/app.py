import gradio as gr
import torch
import yaml
import argparse
from modules.commons import str2bool

# Set up device and torch configurations
if torch.cuda.is_available():
    device = torch.device("cuda")
elif torch.backends.mps.is_available():
    device = torch.device("mps")
else:
    device = torch.device("cpu")

dtype = torch.float16

# Global variables to store model instances
vc_wrapper_v1 = None
vc_wrapper_v2 = None


def load_v2_models(args):
    from hydra.utils import instantiate
    from omegaconf import DictConfig
    cfg = DictConfig(yaml.safe_load(open("configs/v2/vc_wrapper.yaml", "r")))
    vc_wrapper = instantiate(cfg)
    vc_wrapper.load_checkpoints()
    vc_wrapper.to(device)
    vc_wrapper.eval()

    vc_wrapper.setup_ar_caches(max_batch_size=1, max_seq_len=4096, dtype=dtype, device=device)

    if args.compile:
        print("Compiling model with torch.compile...")
        torch._inductor.config.coordinate_descent_tuning = True
        torch._inductor.config.triton.unique_kernel_names = True

        if hasattr(torch._inductor.config, "fx_graph_cache"):
            # Experimental feature to reduce compilation times, will be on by default in future
            torch._inductor.config.fx_graph_cache = True
        vc_wrapper.compile_ar()
        # vc_wrapper.compile_cfm()

    return vc_wrapper


# Wrapper functions for GPU decoration
def convert_voice_v1_wrapper(source_audio_path, target_audio_path, diffusion_steps=10,
                             length_adjust=1.0, inference_cfg_rate=0.7, f0_condition=False,
                             auto_f0_adjust=True, pitch_shift=0, stream_output=True):
    """
    Wrapper function for vc_wrapper.convert_voice that can be decorated with @spaces.GPU
    """
    global vc_wrapper_v1
    from seed_vc_wrapper import SeedVCWrapper
    if vc_wrapper_v1 is None:
        vc_wrapper_v1 = SeedVCWrapper()

    # Use yield from to properly handle the generator
    yield from vc_wrapper_v1.convert_voice(
        source=source_audio_path,
        target=target_audio_path,
        diffusion_steps=diffusion_steps,
        length_adjust=length_adjust,
        inference_cfg_rate=inference_cfg_rate,
        f0_condition=f0_condition,
        auto_f0_adjust=auto_f0_adjust,
        pitch_shift=pitch_shift,
        stream_output=stream_output
    )


def convert_voice_v2_wrapper(source_audio_path, target_audio_path, diffusion_steps=30,
                             length_adjust=1.0, intelligebility_cfg_rate=0.7, similarity_cfg_rate=0.7,
                             top_p=0.7, temperature=0.7, repetition_penalty=1.5,
                             convert_style=False, anonymization_only=False, stream_output=True):
    """
    Wrapper function for vc_wrapper.convert_voice_with_streaming that can be decorated with @spaces.GPU
    """
    global vc_wrapper_v2

    # Use yield from to properly handle the generator
    yield from vc_wrapper_v2.convert_voice_with_streaming(
        source_audio_path=source_audio_path,
        target_audio_path=target_audio_path,
        diffusion_steps=diffusion_steps,
        length_adjust=length_adjust,
        intelligebility_cfg_rate=intelligebility_cfg_rate,
        similarity_cfg_rate=similarity_cfg_rate,
        top_p=top_p,
        temperature=temperature,
        repetition_penalty=repetition_penalty,
        convert_style=convert_style,
        anonymization_only=anonymization_only,
        device=device,
        dtype=dtype,
        stream_output=stream_output
    )


def create_v1_interface():
    # Set up Gradio interface
    description = (
        "元の音声を、参照音声の声質に変換します。音声を2つ選び、下の「変換する」を押してください。<br>"
        "参照音声が25秒を超える場合は、自動的に25秒まで切り詰めます。"
        "元の音声と参照音声の合計が30秒を超える場合は、元の音声を分割して処理します。<br>"
        "詳しくは[Seed-VCの説明](https://github.com/Plachtaa/seed-vc)をご覧ください。")

    inputs = [
        gr.Audio(type="filepath", label="変換元の音声"),
        gr.Audio(type="filepath", label="変換先の声のサンプル（参照音声）"),
        gr.Slider(minimum=1, maximum=200, value=10, step=1, label="生成ステップ数",
                  info="標準は10。高音質にしたい場合は50〜100を試してください。処理時間も長くなります。"),
        gr.Slider(minimum=0.5, maximum=2.0, step=0.1, value=1.0, label="音声の長さ倍率",
                  info="1.0が元の長さです。小さくすると短く、大きくすると長くなります。"),
        gr.Slider(minimum=0.0, maximum=1.0, step=0.1, value=0.7, label="変換の調整値（CFG）",
                  info="通常は0.7のままで使えます。出力の傾向を少し調整します。"),
        gr.Checkbox(label="歌声変換モード（F0を使用）", value=False,
                    info="歌声を変換するときは有効にしてください。"),
        gr.Checkbox(label="音程を参照音声に合わせる", value=True,
                    info="歌声変換モードが有効な場合に、音程を大まかに合わせます。"),
        gr.Slider(label="音程の移動（半音）", minimum=-24, maximum=24, step=1, value=0,
                  info="歌声変換モードが有効な場合だけ適用されます。"),
    ]

    examples = [
        ["examples/source/yae_0.wav", "examples/reference/dingzhen_0.wav", 25, 1.0, 0.7, False, True, 0],
        ["examples/source/jay_0.wav", "examples/reference/azuma_0.wav", 25, 1.0, 0.7, True, True, 0],
        ["examples/source/Wiz Khalifa,Charlie Puth - See You Again [vocals]_[cut_28sec].wav",
         "examples/reference/teio_0.wav", 100, 1.0, 0.7, True, False, 0],
        ["examples/source/TECHNOPOLIS - 2085 [vocals]_[cut_14sec].wav",
         "examples/reference/trump_0.wav", 50, 1.0, 0.7, True, False, -12],
    ]

    outputs = [
        gr.Audio(label="変換結果の試聴（MP3）", streaming=False, format='mp3'),
        gr.Audio(label="変換結果の保存（WAV）", streaming=False, format='wav')
    ]

    return gr.Interface(
        fn=convert_voice_v1_wrapper,
        description=description,
        inputs=inputs,
        outputs=outputs,
        title="Seed-VC 声・歌声変換",
        examples=examples,
        example_labels=["声の変換例", "歌声の変換例 1", "歌声の変換例 2", "歌声の変換例 3"],
        cache_examples=False,
        flagging_mode="never",
        submit_btn="変換する",
        stop_btn="中止する",
        clear_btn="入力を消去",
    )


def create_v2_interface():
    # Set up Gradio interface
    description = (
        "元の音声を参照音声の声質に変換します。参照音声が25秒を超えると、自動的に25秒まで切り詰めます。"
        "2つの音声の合計が30秒を超える場合は、元の音声を分割して処理します。<br>"
        "話し方・感情・アクセントも変えたい場合は、対応する項目を有効にしてください。"
        "匿名化のみを選ぶと参照音声は使わず、モデルが決めた平均的な声に変換します。<br>"
        "[Seed-VC](https://github.com/Plachtaa/seed-vc) / [Vevo](https://github.com/open-mmlab/Amphion/tree/main/models/vc/vevo)"
    )
    inputs = [
        gr.Audio(type="filepath", label="変換元の音声"),
        gr.Audio(type="filepath", label="変換先の声のサンプル（参照音声）"),
        gr.Slider(minimum=1, maximum=200, value=30, step=1, label="生成ステップ数",
                  info="標準は30。高音質にしたい場合は50〜100を試してください。"),
        gr.Slider(minimum=0.5, maximum=2.0, step=0.1, value=1.0, label="音声の長さ倍率",
                  info="1.0が元の長さです。小さくすると短く、大きくすると長くなります。"),
        gr.Slider(minimum=0.0, maximum=1.0, step=0.1, value=0.0, label="発音の明瞭さ",
                  info="発音の聞き取りやすさを調整します。"),
        gr.Slider(minimum=0.0, maximum=1.0, step=0.1, value=0.7, label="参照音声との声質の近さ",
                  info="参照音声への似かたを調整します。"),
        gr.Slider(minimum=0.1, maximum=1.0, step=0.1, value=0.9, label="候補の選択幅",
                  info="音声生成時の候補の選び方を調整します。通常はそのままで使えます。"),
        gr.Slider(minimum=0.1, maximum=2.0, step=0.1, value=1.0, label="生成のランダムさ",
                  info="値を上げると出力が変化しやすくなります。"),
        gr.Slider(minimum=1.0, maximum=3.0, step=0.1, value=1.0, label="繰り返しを避ける強さ",
                  info="音声生成時の繰り返しを抑える設定です。"),
        gr.Checkbox(label="話し方・感情・アクセントも変換する", value=False),
        gr.Checkbox(label="参照音声を使わず匿名化する", value=False),
    ]

    examples = [
        ["examples/source/yae_0.wav", "examples/reference/dingzhen_0.wav", 50, 1.0, 0.0, 0.7, 0.9, 1.0, 1.0, False,
         False],
        ["examples/source/jay_0.wav", "examples/reference/azuma_0.wav", 50, 1.0, 0.0, 0.7, 0.9, 1.0, 1.0, False, False],
    ]

    outputs = [
        gr.Audio(label="変換結果の試聴（MP3）", streaming=False, format='mp3'),
        gr.Audio(label="変換結果の保存（WAV）", streaming=False, format='wav')
    ]

    return gr.Interface(
        fn=convert_voice_v2_wrapper,
        description=description,
        inputs=inputs,
        outputs=outputs,
        title="Seed-VC 声・話し方変換",
        examples=examples,
        example_labels=["声の変換例 1", "声の変換例 2"],
        cache_examples=False,
        flagging_mode="never",
        submit_btn="変換する",
        stop_btn="中止する",
        clear_btn="入力を消去",
    )


def main(args):
    global vc_wrapper_v1, vc_wrapper_v2
    # Create interfaces based on enabled versions
    interfaces = []

    # Load V2 models if enabled
    if args.enable_v2:
        print("Loading V2 models...")
        vc_wrapper_v2 = load_v2_models(args)
        v2_interface = create_v2_interface()
        interfaces.append(("V2 声・話し方変換", v2_interface))

    # Create V1 interface if enabled
    if args.enable_v1:
        print("Creating V1 interface...")
        v1_interface = create_v1_interface()
        interfaces.append(("V1 声・歌声変換", v1_interface))

    # Check if at least one version is enabled
    if not interfaces:
        print("Error: At least one version (V1 or V2) must be enabled.")
        return

    # Create tabs
    # Gradio selects its built-in labels from navigator.language.
    japanese_ui = (
        "<script>Object.defineProperty(navigator, 'language', "
        "{configurable: true, get: () => 'ja'});</script>"
    )
    with gr.Blocks(title="Seed-VC 音声変換", head=japanese_ui) as demo:
        gr.Markdown("# Seed-VC 音声変換")

        if len(interfaces) > 1:
            gr.Markdown("使いたい変換方法を選んでください。")

            with gr.Tabs():
                for tab_name, interface in interfaces:
                    with gr.TabItem(tab_name):
                        interface.render()
        else:
            # If only one version is enabled, don't use tabs
            for _, interface in interfaces:
                interface.render()

    # Launch the combined interface
    demo.launch(inbrowser=True, server_name="127.0.0.1", server_port=7860)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--compile", action="store_true", help="Compile the model using torch.compile")
    parser.add_argument("--enable-v1", action="store_true",
                        help="Enable V1 (Voice & Singing Voice Conversion)")
    parser.add_argument("--enable-v2", action="store_true",
                        help="Enable V2 (Voice & Style Conversion)")
    args = parser.parse_args()
    main(args)
