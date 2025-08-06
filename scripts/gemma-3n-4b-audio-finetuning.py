# ### Unsloth
# 
# `FastModel` supports loading nearly any model now! This includes Vision, Text and Audio models!

# In[ ]:


from unsloth import FastModel
import torch

fourbit_models = [
    # 4bit dynamic quants for superior accuracy and low memory use
    "unsloth/gemma-3n-E4B-it-unsloth-bnb-4bit",
    "unsloth/gemma-3n-E2B-it-unsloth-bnb-4bit",
    # Pretrained models
    "unsloth/gemma-3n-E4B-unsloth-bnb-4bit",
    "unsloth/gemma-3n-E2B-unsloth-bnb-4bit",

    # Other Gemma 3 quants
    "unsloth/gemma-3-1b-it-unsloth-bnb-4bit",
    "unsloth/gemma-3-4b-it-unsloth-bnb-4bit",
    "unsloth/gemma-3-12b-it-unsloth-bnb-4bit",
    "unsloth/gemma-3-27b-it-unsloth-bnb-4bit",
] # More models at https://huggingface.co/unsloth

model, processor = FastModel.from_pretrained(
    model_name = "unsloth/gemma-3n-E2B-it", # Or "unsloth/gemma-3n-E2B-it"
    dtype = None, # None for auto detection
    max_seq_length = 1024, # Choose any for long context!
    load_in_4bit = True,  # 4 bit quantization to reduce memory
    full_finetuning = False, # [NEW!] We have full finetuning now!
    # token = "hf_...", # use one if using gated models
)


# # Gemma 3N can process Text, Vision and Audio!
# 
# Let's first experience how Gemma 3N can handle multimodal inputs. We use Gemma 3N's recommended settings of `temperature = 1.0, top_p = 0.95, top_k = 64` but for this example we use `do_sample = False` to disable sampling for ASR (speech recognition) to get determinstic outputs.
# 
# ### Audio finetuning for Gemma 3N
# 
# In this notebook, our goal is to transcribe German with higher accuracy by finetuning Gemma 3N!

# In[ ]:


from transformers import TextStreamer
# Helper function for inference
def do_gemma_3n_inference(messages, max_new_tokens = 128):
    _ = model.generate(
        **processor.apply_chat_template(
            messages,
            add_generation_prompt = True, # Must add for generation
            tokenize = True,
            return_dict = True,
            return_tensors = "pt",
        ).to("cuda"),
        max_new_tokens = max_new_tokens,
        do_sample = False,
        streamer = TextStreamer(processor, skip_prompt = True),
    )


# <h3>Let's Evaluate Gemma 3N Baseline Performance on German Transcription</h2>

# In[ ]:


from datasets import load_dataset, Audio, concatenate_datasets, load_from_disk

#dataset = load_dataset("english_dialects_asl_gloss_vllm_batched", split="test")
dataset = load_from_disk("english_dialects_asl_gloss_vllm_batched")
dataset.cleanup_cache_files()

# Select a single audio sample to reserve for testing.
# This index is chosen from the full dataset before we create the smaller training split.
test_audio = dataset[1000]
dataset = dataset.cast_column("audio", Audio(sampling_rate=16000))


# In[ ]:


from IPython.display import Audio, display
print(test_audio['text'])
print("#[" + test_audio["asl_gloss"] + "]#")
Audio(test_audio['audio']['array'],rate=test_audio['audio']['sampling_rate'])


# In[ ]:


messages = [
    {
        "role": "system",
        "content": [
            {
                "type": "text",
                "text": "You are an assistant that transcribes speech accurately.",
            }
        ],
    },
    {
        "role": "user",
        "content": [
            {"type": "audio", "audio": test_audio['audio']['array']},
            {"type": "text", "text": "Please transcribe this audio."}
        ]
    }
]

do_gemma_3n_inference(messages, max_new_tokens = 256)


# <h3>The baseline mdel performance: 24.32% Word Error Rate (WER) for this sample !</h3>

# # Let's finetune Gemma 3N!
# 
# You can finetune the vision and text and audio parts

# In[ ]:


model = FastModel.get_peft_model(
    model,
    finetune_vision_layers     = False, # False if not finetuning vision layers
    finetune_language_layers   = True, # False if not finetuning language layers
    finetune_attention_modules = True, # False if not finetuning attention layers
    finetune_mlp_modules       = True, # False if not finetuning MLP layers

    r = 8,                           # The larger, the higher the accuracy, but might overfit
    lora_alpha = 16,                 # Recommended alpha == r at least
    lora_dropout = 0,
    bias = "none",
    random_state = 3407,
    use_rslora = False,              # We support rank stabilized LoRA
    loftq_config = None,             # And LoftQ
    target_modules = [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",

        # Audio layers
        "post", "linear_start", "linear_end",
        "embedding_projection",
    ],
    modules_to_save=[
        "lm_head",
        "embed_tokens",
        "embed_audio",
    ],
)


# <a name="Data"></a>
# ### Data Prep
# We adapt the `kadirnar/Emilia-DE-B000000` dataset for our German ASR task using Gemma 3N multi-modal chat format. Each audio-text pair is structured into a conversation with `system`, `user`, and `assistant` roles. The processor then converts this into the final training format:
# 
# ```
# <bos><start_of_turn>system
# You are an assistant that transcribes speech accurately.<end_of_turn>
# <start_of_turn>user
# <audio>Please transcribe this audio.<end_of_turn>
# <start_of_turn>model
# Ich, ich rechne direkt mich an.<end_of_turn>
# ```

# In[ ]:


def format_intersection_data(samples: dict) -> dict[str, list]:
    """Format intersection dataset to match expected message format"""
    formatted_samples = {"messages": []}
    for idx in range(len(samples["audio"])):
        audio = samples["audio"][idx]["array"]
        label = str(samples["text"][idx])
        asl_gloss = str(samples["asl_gloss"][idx])

        message = [
            {
                "role": "system",
                "content": [
                    {
                        "type": "text",
                        "text": "You are an assistant that transcribes speech as ASLGLoss",
                    }
                ],
            },
            {
                "role": "user",
                "content": [
                    {"type": "audio", "audio": audio},
                    {"type": "text", "text": "Please transcribe this audio as ASLGLoss"}
                ]
            },
            {
                "role": "assistant",
                "content":[{"type": "text", "text": label + "<ASL>" + str(samples["asl_gloss"][idx]) +"</ASL>"}]
            }
        ]
        formatted_samples["messages"].append(message)
    return formatted_samples


# In[ ]:


dataset = dataset.map(format_intersection_data, batched=True, batch_size=4, num_proc=4)


# In[ ]:


def collate_fn(examples):
    texts = []
    audios = []
    
    for example in examples:
        # Apply chat template to get text
        text = processor.apply_chat_template(
            example["messages"], tokenize=False, add_generation_prompt=False
        ).strip()
        texts.append(text)
    
        # Extract audios
        audios.append(example["audio"]["array"])
    
    # Tokenize the texts and process the images
    batch = processor(
        text=texts, audio=audios, return_tensors="pt", padding=True
    )
    
    # The labels are the input_ids, and we mask the padding tokens in the loss computation
    labels = batch["input_ids"].clone()
    
    # Use Gemma3n specific token masking
    labels[labels == processor.tokenizer.pad_token_id] = -100
    if hasattr(processor.tokenizer, 'image_token_id'):
        labels[labels == processor.tokenizer.image_token_id] = -100
    if hasattr(processor.tokenizer, 'audio_token_id'):
        labels[labels == processor.tokenizer.audio_token_id] = -100
    if hasattr(processor.tokenizer, 'boi_token_id'):
        labels[labels == processor.tokenizer.boi_token_id] = -100
    if hasattr(processor.tokenizer, 'eoi_token_id'):
        labels[labels == processor.tokenizer.eoi_token_id] = -100
    
    
    batch["labels"] = labels
    return batch


# <a name="Train"></a>
# ### Train the model
# Now let's use Huggingface TRL's `SFTTrainer`! More docs here: [TRL SFT docs](https://huggingface.co/docs/trl/sft_trainer). We train for one full epoch (num_train_epochs=1) to get a meaningful result.

# In[ ]:


from trl import SFTTrainer, SFTConfig


trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    processing_class=processor.tokenizer,
    data_collator=collate_fn,
    args = SFTConfig(
        per_device_train_batch_size = 4,
        gradient_accumulation_steps = 1,
        warmup_ratio = 0.1,
        max_steps=12000,
        #num_train_epochs = 2,          # Set this instead of max_steps for full training runs
        learning_rate = 5e-5,
        logging_steps = 10,
        save_strategy="steps",
        save_steps=500,
        optim = "adamw_8bit",
        weight_decay = 0.01,
        lr_scheduler_type = "cosine",
        seed = 3407,
        output_dir = "asl_gloss",
        report_to = "none",            # For Weights and Biases

        # You MUST put the below items for audio finetuning:
        remove_unused_columns = False,
        dataset_text_field = "",
        dataset_kwargs = {"skip_prepare_dataset": True},
        dataset_num_proc = 2,
        max_length = 2048,
    )
)


# In[ ]:


# @title Show current memory stats
gpu_stats = torch.cuda.get_device_properties(0)
start_gpu_memory = round(torch.cuda.max_memory_reserved() / 1024 / 1024 / 1024, 3)
max_memory = round(gpu_stats.total_memory / 1024 / 1024 / 1024, 3)
print(f"GPU = {gpu_stats.name}. Max memory = {max_memory} GB.")
print(f"{start_gpu_memory} GB of memory reserved.")


# # Let's train the model!
# 
# To resume a training run, set `trainer.train(resume_from_checkpoint = True)`

# In[ ]:


trainer_stats = trainer.train()
#trainer_stats = trainer.train()


# In[ ]:


# @title Show final memory and time stats
used_memory = round(torch.cuda.max_memory_reserved() / 1024 / 1024 / 1024, 3)
used_memory_for_lora = round(used_memory - start_gpu_memory, 3)
used_percentage = round(used_memory / max_memory * 100, 3)
lora_percentage = round(used_memory_for_lora / max_memory * 100, 3)
print(f"{trainer_stats.metrics['train_runtime']} seconds used for training.")
print(
    f"{round(trainer_stats.metrics['train_runtime']/60, 2)} minutes used for training."
)
print(f"Peak reserved memory = {used_memory} GB.")
print(f"Peak reserved memory for training = {used_memory_for_lora} GB.")
print(f"Peak reserved memory % of max memory = {used_percentage} %.")
print(f"Peak reserved memory for training % of max memory = {lora_percentage} %.")


# <a name="Inference"></a>
# ### Inference
# Let's run the model via Unsloth native inference! According to the `Gemma-3` team, the recommended settings for inference are `temperature = 1.0, top_p = 0.95, top_k = 64` but for this example we use `do_sample=False` for ASR.

# In[ ]:


messages = [
    {
        "role": "system",
        "content": [
            {
                "type": "text",
                "text": "You are an assistant that transcribes speech as ASLGLoss",
            }
        ],
    },
    {
        "role": "user",
        "content": [
            {"type": "audio", "audio": "LJ012-0054.wav"},
            {"type": "text", "text": "Please transcribe this audio as ASLGLoss"}
        ]
    }
]

do_gemma_3n_inference(messages, max_new_tokens = 256)


# <h3> With only 3,000 German speech samples, we reduced the Word Error Rate (WER) from 24.32% to 16.22%. This represents a significant 33.31% relative error rate reduction ! </h4>

# <a name="Save"></a>
# ### Saving, loading finetuned models
# To save the final model as LoRA adapters, either use Huggingface's `push_to_hub` for an online save or `save_pretrained` for a local save.
# 
# **[NOTE]** This ONLY saves the LoRA adapters, and not the full model. To save to 16bit or GGUF, scroll down!

# In[ ]:


model.save_pretrained("gemma-3n")  # Local saving
processor.save_pretrained("gemma-3n")
print("saved models")
# model.push_to_hub("HF_ACCOUNT/gemma-3n", token = "...") # Online saving
# processor.push_to_hub("HF_ACCOUNT/gemma-3n", token = "...") # Online saving


# Now if you want to load the LoRA adapters we just saved for inference, set `False` to `True`:

# In[ ]:


if False:
    from unsloth import FastModel
    model, processor = FastModel.from_pretrained(
        model_name = "gemma-3n", # YOUR MODEL YOU USED FOR TRAINING
        max_seq_length = 2048,
        load_in_4bit = True,
    )

messages = [{
    "role": "user",
    "content": [{"type" : "text", "text" : "What is Gemma-3N?",}]
}]
inputs = processor.apply_chat_template(
    messages,
    add_generation_prompt = True, # Must add for generation
    return_tensors = "pt",
    tokenize = True,
    return_dict = True,
).to("cuda")

from transformers import TextStreamer
_ = model.generate(
    **inputs,
    max_new_tokens = 128, # Increase for longer outputs!
    # Recommended Gemma-3 settings!
    temperature = 1.0, top_p = 0.95, top_k = 64,
    streamer = TextStreamer(processor, skip_prompt = True),
)


# ### Saving to float16 for VLLM
# 
# We also support saving to `float16` directly for deployment! We save it in the folder `gemma-3N-finetune`. Set `if False` to `if True` to let it run!

# In[ ]:


if True: # Change to True to save finetune!
    model.save_pretrained_merged("gemma-3n", processor)


# If you want to upload / push to your Hugging Face account, set `if False` to `if True` and add your Hugging Face token and upload location!

# In[ ]:


if True: # Change to True to upload finetune
    model.push_to_hub_merged(
        "tinisoft/gemma-3n-aslgloss", processor,
    )


# ### GGUF / llama.cpp Conversion
# To save to `GGUF` / `llama.cpp`, we support it natively now for all models! For now, you can convert easily to `Q8_0, F16 or BF16` precision. `Q4_K_M` for 4bit will come later!

# In[ ]:


if False: # Change to True to save to GGUF
    model.save_pretrained_gguf(
        "gemma-3N-finetune",
        quantization_type = "BF16", # For now only Q8_0, BF16, F16 supported
    )


# Likewise, if you want to instead push to GGUF to your Hugging Face account, set `if False` to `if True` and add your Hugging Face token and upload location!

# In[ ]:


if False: # Change to True to upload GGUF
    model.push_to_hub_gguf(
        "gemma-3N-finetune",
        quantization_type = "Q8_0", # Only Q8_0, BF16, F16 supported
        repo_id = "HF_ACCOUNT/gemma-3N-finetune-gguf",
        token = "hf_...",
    )


# Now, use the `gemma-3N-finetune.gguf` file or `gemma-3N-finetune-Q4_K_M.gguf` file in llama.cpp or a UI based system like Jan or Open WebUI. You can install Jan [here](https://github.com/janhq/jan) and Open WebUI [here](https://github.com/open-webui/open-webui)
# 
# And we're done! If you have any questions on Unsloth, we have a [Discord](https://discord.gg/unsloth) channel! If you find any bugs or want to keep updated with the latest LLM stuff, or need help, join projects etc, feel free to join our Discord!
# 
# Some other links:
# 1. Train your own reasoning model - Llama GRPO notebook [Free Colab](https://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Llama3.1_(8B)-GRPO.ipynb)
# 2. Saving finetunes to Ollama. [Free notebook](https://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Llama3_(8B)-Ollama.ipynb)
# 3. Llama 3.2 Vision finetuning - Radiography use case. [Free Colab](https://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Llama3.2_(11B)-Vision.ipynb)
# 6. See notebooks for DPO, ORPO, Continued pretraining, conversational finetuning and more on our [documentation](https://docs.unsloth.ai/get-started/unsloth-notebooks)!
# 
# ## Gemma 3N Notebook collection:
# 1. Gemma 3N **Multimodal inference + conversational finetuning** [Kaggle Notebook](https://www.kaggle.com/code/danielhanchen/gemma-3n-4b-multimodal-finetuning-inference)
# 2. Gemma 3N **Vision finetuning** [Kaggle Notebook](https://www.kaggle.com/code/danielhanchen/gemma-3n-4b-vision-finetuning)
# 3. Gemma 3N **Audio finetuning** [Kaggle Notebook](https://www.kaggle.com/code/danielhanchen/gemma-3n-4b-audio-finetuning) *⬅️ Your are here*
# 
# <div class="align-center">
#   <a href="https://unsloth.ai"><img src="https://github.com/unslothai/unsloth/raw/main/images/unsloth%20new%20logo.png" width="115"></a>
#   <a href="https://discord.gg/unsloth"><img src="https://github.com/unslothai/unsloth/raw/main/images/Discord.png" width="145"></a>
#   <a href="https://docs.unsloth.ai/"><img src="https://github.com/unslothai/unsloth/blob/main/images/documentation%20green%20button.png?raw=true" width="125"></a>
# 
#   Join Discord if you need help + ⭐️ <i>Star us on <a href="https://github.com/unslothai/unsloth">Github</a> </i> ⭐️
# </div>
# 
