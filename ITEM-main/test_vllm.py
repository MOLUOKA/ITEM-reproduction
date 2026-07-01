from vllm import LLM
from vllm import SamplingParams

def main():
    llm = LLM(
        model="./models/Qwen3-8B-GPTQ",
        #model="Qwen/Qwen3-0.6B",
        trust_remote_code=True,
        gpu_memory_utilization=0.8,
        enforce_eager=True,
        max_model_len=4096
    )

    outputs = llm.generate(
        ["你好，请介绍一下自己。"],
        SamplingParams(
            temperature=0.7,
            max_tokens=1024
        )
    )

    print(outputs[0].outputs[0].text)

if __name__ == "__main__":
    main()