# Flux Kontext ComfyUI Docker Image with Embedded Models
FROM runpod/worker-comfyui:5.2.0-base

# Set working directory
WORKDIR /comfyui

# Install system dependencies for custom nodes and model downloads
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    build-essential \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install huggingface-hub for downloading models
RUN pip install huggingface-hub --upgrade

# Update ComfyUI to latest version
RUN cd /comfyui && \
    git pull origin master || git fetch --all && git reset --hard origin/master && \
    pip install -r requirements.txt --upgrade

# Install your specific custom nodes with dependencies
RUN cd /comfyui/custom_nodes && \
    \
    # ComfyUI-Easy-Use
    echo "Installing ComfyUI-Easy-Use..." && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    cd ComfyUI-Easy-Use && \
    pip install -r requirements.txt --no-deps --break-system-packages && \
    cd .. && \
    \
    # rgthree-comfy  
    echo "Installing rgthree-comfy..." && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    pip install -r requirements.txt --no-deps --break-system-packages && \
    cd .. && \
    \
    # ComfyUI_essentials
    echo "Installing ComfyUI_essentials..." && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    cd ComfyUI_essentials && \
    pip install -r requirements.txt --no-deps --break-system-packages && \
    cd ..

# Ensure model directories exist
RUN mkdir -p /comfyui/models/diffusion_models && \
    mkdir -p /comfyui/models/clip && \
    mkdir -p /comfyui/models/vae && \
    mkdir -p /comfyui/models/upscale_models

# Download FLUX Kontext models
RUN echo "🚀 Downloading FLUX Kontext models..." && \
    \
    # Download main FLUX Kontext model (23.8 GB)
    echo "📥 Downloading FLUX Kontext dev model (23.8 GB)..." && \
    huggingface-cli download black-forest-labs/FLUX.1-Kontext-dev \
        flux1-kontext-dev.safetensors \
        --local-dir /comfyui/models/diffusion_models \
        --local-dir-use-symlinks False && \
    \
    # Download VAE model (335 MB)
    echo "📥 Downloading FLUX VAE model (335 MB)..." && \
    huggingface-cli download black-forest-labs/FLUX.1-Kontext-dev \
        ae.safetensors \
        --local-dir /comfyui/models/vae \
        --local-dir-use-symlinks False && \
    \
    # Download CLIP L model (246 MB)
    echo "📥 Downloading CLIP L model (246 MB)..." && \
    huggingface-cli download comfyanonymous/flux_text_encoders \
        clip_l.safetensors \
        --local-dir /comfyui/models/clip \
        --local-dir-use-symlinks False && \
    \
    # Download T5 model (9.79 GB)
    echo "📥 Downloading T5 XXL FP16 model (9.79 GB)..." && \
    huggingface-cli download comfyanonymous/flux_text_encoders \
        t5xxl_fp16.safetensors \
        --local-dir /comfyui/models/clip \
        --local-dir-use-symlinks False

# Verify all models were downloaded correctly
RUN echo "🔍 Verifying downloaded models..." && \
    echo "📊 Model Inventory:" && \
    echo "Diffusion Models:" && \
    ls -lh /comfyui/models/diffusion_models/ && \
    echo "VAE Models:" && \
    ls -lh /comfyui/models/vae/ && \
    echo "CLIP/Text Encoder Models:" && \
    ls -lh /comfyui/models/clip/ && \
    \
    # Verify specific required files exist
    echo "🎯 Checking required models:" && \
    test -f "/comfyui/models/diffusion_models/flux1-kontext-dev.safetensors" && echo "✅ FLUX Kontext model found" || echo "❌ FLUX Kontext model missing" && \
    test -f "/comfyui/models/vae/ae.safetensors" && echo "✅ VAE model found" || echo "❌ VAE model missing" && \
    test -f "/comfyui/models/clip/clip_l.safetensors" && echo "✅ CLIP L model found" || echo "❌ CLIP L model missing" && \
    test -f "/comfyui/models/clip/t5xxl_fp16.safetensors" && echo "✅ T5 model found" || echo "❌ T5 model missing"

# Create enhanced entrypoint that shows model inventory
RUN echo '#!/bin/bash' > /enhanced_entrypoint.sh && \
    echo 'echo "🚀 Starting Flux Kontext ComfyUI..."' >> /enhanced_entrypoint.sh && \
    echo 'echo "📍 Container: bilal2912/comfyui-flux-kontext (with embedded models)"' >> /enhanced_entrypoint.sh && \
    echo 'echo ""' >> /enhanced_entrypoint.sh && \
    echo '' >> /enhanced_entrypoint.sh && \
    echo '# Show embedded model inventory' >> /enhanced_entrypoint.sh && \
    echo 'echo "📊 === EMBEDDED MODEL INVENTORY ==="' >> /enhanced_entrypoint.sh && \
    echo 'echo "Diffusion Models:"' >> /enhanced_entrypoint.sh && \
    echo 'ls -la /comfyui/models/diffusion_models/ | grep "\.safetensors" || echo "  ❌ No diffusion models found"' >> /enhanced_entrypoint.sh && \
    echo 'echo ""' >> /enhanced_entrypoint.sh && \
    echo 'echo "CLIP Models:"' >> /enhanced_entrypoint.sh && \
    echo 'ls -la /comfyui/models/clip/ | grep "\.safetensors" || echo "  ❌ No CLIP models found"' >> /enhanced_entrypoint.sh && \
    echo 'echo ""' >> /enhanced_entrypoint.sh && \
    echo 'echo "VAE Models:"' >> /enhanced_entrypoint.sh && \
    echo 'ls -la /comfyui/models/vae/ | grep "\.safetensors" || echo "  ❌ No VAE models found"' >> /enhanced_entrypoint.sh && \
    echo 'echo ""' >> /enhanced_entrypoint.sh && \
    echo 'if [ -f "/comfyui/models/diffusion_models/flux1-kontext-dev.safetensors" ] && [ -f "/comfyui/models/clip/clip_l.safetensors" ] && [ -f "/comfyui/models/vae/ae.safetensors" ]; then' >> /enhanced_entrypoint.sh && \
    echo '  echo "🎉 SUCCESS: All required Flux Kontext models are embedded and ready!"' >> /enhanced_entrypoint.sh && \
    echo 'else' >> /enhanced_entrypoint.sh && \
    echo '  echo "⚠️  WARNING: Some required models are missing"' >> /enhanced_entrypoint.sh && \
    echo 'fi' >> /enhanced_entrypoint.sh && \
    echo 'echo ""' >> /enhanced_entrypoint.sh && \
    echo '' >> /enhanced_entrypoint.sh && \
    echo '# Verify custom nodes are available' >> /enhanced_entrypoint.sh && \
    echo 'echo "🧩 Custom Nodes Available:"' >> /enhanced_entrypoint.sh && \
    echo 'ls -1 /comfyui/custom_nodes/ | grep -v example | grep -v websocket' >> /enhanced_entrypoint.sh && \
    echo 'echo ""' >> /enhanced_entrypoint.sh && \
    echo '' >> /enhanced_entrypoint.sh && \
    echo '# Start the original process' >> /enhanced_entrypoint.sh && \
    echo 'echo "🎯 Starting ComfyUI server..."' >> /enhanced_entrypoint.sh && \
    echo 'exec "$@"' >> /enhanced_entrypoint.sh && \
    chmod +x /enhanced_entrypoint.sh

# Set proper permissions
RUN chmod -R 755 /comfyui && \
    chown -R root:root /comfyui

# Use enhanced entrypoint
ENTRYPOINT ["/enhanced_entrypoint.sh"]

# Keep the original CMD from base image
CMD ["/start.sh"]