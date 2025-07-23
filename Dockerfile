# Hybrid Flux Kontext ComfyUI Docker Image
# Custom nodes embedded (for reliability) + Models from network volume (for flexibility)
FROM runpod/worker-comfyui:5.2.0-base

# Set working directory
WORKDIR /comfyui

# Install system dependencies for custom nodes
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    build-essential \
    rsync \
    unzip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Update ComfyUI to latest version
RUN cd /comfyui && \
    git pull origin master || git fetch --all && git reset --hard origin/master && \
    pip install -r requirements.txt --upgrade

# Install your specific custom nodes with dependencies (EMBEDDED APPROACH)
RUN cd /comfyui/custom_nodes && \
    echo "📥 Installing ComfyUI-Easy-Use..." && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    cd ComfyUI-Easy-Use && \
    pip install -r requirements.txt --no-deps --break-system-packages --quiet && \
    echo "✅ ComfyUI-Easy-Use installed successfully" && \
    cd .. && \
    \
    echo "📥 Installing rgthree-comfy..." && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    pip install -r requirements.txt --no-deps --break-system-packages --quiet && \
    echo "✅ rgthree-comfy installed successfully" && \
    cd .. && \
    \
    echo "📥 Installing ComfyUI_essentials..." && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    cd ComfyUI_essentials && \
    pip install -r requirements.txt --no-deps --break-system-packages --quiet && \
    echo "✅ ComfyUI_essentials installed successfully" && \
    cd .. && \
    \
    echo "🧩 Custom nodes installation completed!"

# Ensure model directories exist (will be populated from network volume)
RUN mkdir -p /comfyui/models/diffusion_models && \
    mkdir -p /comfyui/models/clip && \
    mkdir -p /comfyui/models/vae && \
    mkdir -p /comfyui/models/upscale_models && \
    mkdir -p /comfyui/models/loras && \
    mkdir -p /comfyui/models/controlnet && \
    mkdir -p /comfyui/models/embeddings && \
    mkdir -p /comfyui/models/checkpoints

# Create optimized model setup script for network volume (MODELS ONLY)
RUN echo '#!/bin/bash' > /setup_models.sh && \
    echo 'echo "📦 Setting up models from RunPod network volume..."' >> /setup_models.sh && \
    echo 'echo "🧩 Custom nodes: Already embedded and ready!"' >> /setup_models.sh && \
    echo 'echo "================================================"' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo '# Function to efficiently link models from network volume' >> /setup_models.sh && \
    echo 'setup_models() {' >> /setup_models.sh && \
    echo '    local source_path="$1"' >> /setup_models.sh && \
    echo '    local model_type="$2"' >> /setup_models.sh && \
    echo '    local dest_path="$3"' >> /setup_models.sh && \
    echo '    ' >> /setup_models.sh && \
    echo '    if [ ! -d "$source_path" ]; then' >> /setup_models.sh && \
    echo '        echo "  ⚠️  $source_path not found, skipping $model_type models"' >> /setup_models.sh && \
    echo '        return 0' >> /setup_models.sh && \
    echo '    fi' >> /setup_models.sh && \
    echo '    ' >> /setup_models.sh && \
    echo '    echo "  📂 Setting up $model_type models: $source_path → $dest_path"' >> /setup_models.sh && \
    echo '    local count=0' >> /setup_models.sh && \
    echo '    ' >> /setup_models.sh && \
    echo '    # Link all supported model file types' >> /setup_models.sh && \
    echo '    for pattern in "*.safetensors" "*.ckpt" "*.bin" "*.pt" "*.pth"; do' >> /setup_models.sh && \
    echo '        for file in "$source_path"/$pattern; do' >> /setup_models.sh && \
    echo '            if [ -f "$file" ]; then' >> /setup_models.sh && \
    echo '                local filename=$(basename "$file")' >> /setup_models.sh && \
    echo '                local dest_file="$dest_path/$filename"' >> /setup_models.sh && \
    echo '                ' >> /setup_models.sh && \
    echo '                # Skip if already exists' >> /setup_models.sh && \
    echo '                if [ -e "$dest_file" ]; then' >> /setup_models.sh && \
    echo '                    continue' >> /setup_models.sh && \
    echo '                fi' >> /setup_models.sh && \
    echo '                ' >> /setup_models.sh && \
    echo '                # Create symlink for instant access' >> /setup_models.sh && \
    echo '                ln -sf "$file" "$dest_file" 2>/dev/null && {' >> /setup_models.sh && \
    echo '                    count=$((count + 1))' >> /setup_models.sh && \
    echo '                } || {' >> /setup_models.sh && \
    echo '                    echo "    ⚠️  Failed to link: $filename"' >> /setup_models.sh && \
    echo '                }' >> /setup_models.sh && \
    echo '            fi' >> /setup_models.sh && \
    echo '        done' >> /setup_models.sh && \
    echo '    done' >> /setup_models.sh && \
    echo '    ' >> /setup_models.sh && \
    echo '    echo "    ✅ $count $model_type model(s) linked"' >> /setup_models.sh && \
    echo '    return $count' >> /setup_models.sh && \
    echo '}' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo '# Function to search and link specific models by name' >> /setup_models.sh && \
    echo 'find_and_link_model() {' >> /setup_models.sh && \
    echo '    local search_base="$1"' >> /setup_models.sh && \
    echo '    local model_name="$2"' >> /setup_models.sh && \
    echo '    local dest_path="$3"' >> /setup_models.sh && \
    echo '    local display_name="$4"' >> /setup_models.sh && \
    echo '    ' >> /setup_models.sh && \
    echo '    local found_file=$(find "$search_base" -name "$model_name" -type f 2>/dev/null | head -1)' >> /setup_models.sh && \
    echo '    if [ -n "$found_file" ] && [ -f "$found_file" ]; then' >> /setup_models.sh && \
    echo '        ln -sf "$found_file" "$dest_path/$(basename "$found_file")" && \' >> /setup_models.sh && \
    echo '            echo "    🔗 $display_name: Found and linked" || \' >> /setup_models.sh && \
    echo '            echo "    ❌ $display_name: Link failed"' >> /setup_models.sh && \
    echo '        return 0' >> /setup_models.sh && \
    echo '    else' >> /setup_models.sh && \
    echo '        echo "    ⚠️  $display_name: Not found"' >> /setup_models.sh && \
    echo '        return 1' >> /setup_models.sh && \
    echo '    fi' >> /setup_models.sh && \
    echo '}' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo '# Main setup logic - try different network volume mount points' >> /setup_models.sh && \
    echo 'VOLUME_FOUND=false' >> /setup_models.sh && \
    echo 'MODELS_LINKED=0' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo 'for base_path in /runpod-volume/ComfyUI/models /runpod-volume/ComfyUI /workspace/ComfyUI/models /workspace/ComfyUI; do' >> /setup_models.sh && \
    echo '    if [ -d "$base_path" ]; then' >> /setup_models.sh && \
    echo '        echo "🎯 Found volume at: $base_path"' >> /setup_models.sh && \
    echo '        VOLUME_FOUND=true' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        # Setup different model types with proper organization' >> /setup_models.sh && \
    echo '        setup_models "$base_path/diffusion_models" "diffusion" "/comfyui/models/diffusion_models"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/unet" "diffusion" "/comfyui/models/diffusion_models"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/checkpoints" "checkpoint" "/comfyui/models/checkpoints"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/clip" "CLIP" "/comfyui/models/clip"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/text_encoders" "text_encoder" "/comfyui/models/clip"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/vae" "VAE" "/comfyui/models/vae"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/loras" "LoRA" "/comfyui/models/loras"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/controlnet" "ControlNet" "/comfyui/models/controlnet"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/upscale_models" "upscaler" "/comfyui/models/upscale_models"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        setup_models "$base_path/embeddings" "embedding" "/comfyui/models/embeddings"' >> /setup_models.sh && \
    echo '        MODELS_LINKED=$((MODELS_LINKED + $?))' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        # Special search for FLUX Kontext models (can be anywhere in volume)' >> /setup_models.sh && \
    echo '        echo "  🔍 Searching for specific FLUX Kontext models..."' >> /setup_models.sh && \
    echo '        find_and_link_model "$base_path" "flux1-kontext-dev.safetensors" "/comfyui/models/diffusion_models" "FLUX Kontext model"' >> /setup_models.sh && \
    echo '        find_and_link_model "$base_path" "*kontext*.safetensors" "/comfyui/models/diffusion_models" "FLUX Kontext variants"' >> /setup_models.sh && \
    echo '        find_and_link_model "$base_path" "ae.safetensors" "/comfyui/models/vae" "FLUX VAE model"' >> /setup_models.sh && \
    echo '        find_and_link_model "$base_path" "clip_l.safetensors" "/comfyui/models/clip" "CLIP-L model"' >> /setup_models.sh && \
    echo '        find_and_link_model "$base_path" "t5xxl*fp16*.safetensors" "/comfyui/models/clip" "T5-XXL FP16 model"' >> /setup_models.sh && \
    echo '        find_and_link_model "$base_path" "t5xxl*fp8*.safetensors" "/comfyui/models/clip" "T5-XXL FP8 model"' >> /setup_models.sh && \
    echo '        ' >> /setup_models.sh && \
    echo '        break  # Use first valid volume found' >> /setup_models.sh && \
    echo '    fi' >> /setup_models.sh && \
    echo 'done' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo '# Status summary and verification' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    echo 'echo "📊 === SETUP SUMMARY ==="' >> /setup_models.sh && \
    echo '[ "$VOLUME_FOUND" = "true" ] && echo "✅ Network volume: Found and processed" || echo "❌ Network volume: Not found"' >> /setup_models.sh && \
    echo 'echo "🔗 Total models linked: $MODELS_LINKED"' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo '# Show whats available' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    echo 'echo "🧩 Embedded Custom Nodes (Ready):"' >> /setup_models.sh && \
    echo 'ls -1 /comfyui/custom_nodes/ 2>/dev/null | grep -v __pycache__ | grep -v websocket | grep -v example || echo "  No custom nodes found"' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    echo 'echo "📦 Models Summary:"' >> /setup_models.sh && \
    echo 'for model_type in diffusion_models vae clip checkpoints loras; do' >> /setup_models.sh && \
    echo '    local count=$(ls /comfyui/models/$model_type/*.{safetensors,ckpt,bin,pt} 2>/dev/null | wc -l)' >> /setup_models.sh && \
    echo '    echo "  $(echo $model_type | tr _ " " | awk "{for(i=1;i<=NF;i++){\$i=toupper(substr(\$i,1,1)) tolower(substr(\$i,2))}}1"): $count model(s)"' >> /setup_models.sh && \
    echo 'done' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo '# FLUX Kontext specific verification' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    echo 'echo "🎯 FLUX Kontext Requirements Check:"' >> /setup_models.sh && \
    echo '[ -f "/comfyui/models/diffusion_models/flux1-kontext-dev.safetensors" ] && echo "  ✅ FLUX Kontext model: Ready" || echo "  ❌ FLUX Kontext model: Missing"' >> /setup_models.sh && \
    echo '[ -f "/comfyui/models/vae/ae.safetensors" ] && echo "  ✅ FLUX VAE model: Ready" || echo "  ❌ FLUX VAE model: Missing"' >> /setup_models.sh && \
    echo '[ -f "/comfyui/models/clip/clip_l.safetensors" ] && echo "  ✅ CLIP-L model: Ready" || echo "  ❌ CLIP-L model: Missing"' >> /setup_models.sh && \
    echo 'find /comfyui/models/clip/ -name "t5xxl*.safetensors" 2>/dev/null | grep -q . && echo "  ✅ T5-XXL model: Ready" || echo "  ❌ T5-XXL model: Missing"' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    echo 'if [ "$VOLUME_FOUND" = "false" ]; then' >> /setup_models.sh && \
    echo '    echo "⚠️  WARNING: No network volume found!"' >> /setup_models.sh && \
    echo '    echo "💡 Expected network volume structure:"' >> /setup_models.sh && \
    echo '    echo "   /runpod-volume/models/"' >> /setup_models.sh && \
    echo '    echo "   ├── diffusion_models/"' >> /setup_models.sh && \
    echo '    echo "   │   └── flux1-kontext-dev.safetensors"' >> /setup_models.sh && \
    echo '    echo "   ├── vae/"' >> /setup_models.sh && \
    echo '    echo "   │   └── ae.safetensors"' >> /setup_models.sh && \
    echo '    echo "   └── clip/"' >> /setup_models.sh && \
    echo '    echo "       ├── clip_l.safetensors"' >> /setup_models.sh && \
    echo '    echo "       └── t5xxl_fp16.safetensors"' >> /setup_models.sh && \
    echo '    echo ""' >> /setup_models.sh && \
    echo '    echo "🚨 Models are required for the workflow to function!"' >> /setup_models.sh && \
    echo 'elif [ "$MODELS_LINKED" -eq 0 ]; then' >> /setup_models.sh && \
    echo '    echo "⚠️  WARNING: Network volume found but no models were linked!"' >> /setup_models.sh && \
    echo '    echo "💡 Please check that model files exist in the volume"' >> /setup_models.sh && \
    echo 'else' >> /setup_models.sh && \
    echo '    echo "🎉 SUCCESS: Models linked from network volume!"' >> /setup_models.sh && \
    echo '    echo "🚀 System is ready for FLUX Kontext workflows!"' >> /setup_models.sh && \
    echo 'fi' >> /setup_models.sh && \
    echo '' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    echo 'echo "💾 Disk Usage Summary:"' >> /setup_models.sh && \
    echo 'df -h /comfyui 2>/dev/null || echo "Unable to show disk usage"' >> /setup_models.sh && \
    echo 'echo ""' >> /setup_models.sh && \
    chmod +x /setup_models.sh

# Create hybrid entrypoint
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'echo "🚀 Hybrid Flux Kontext ComfyUI Starting..."' >> /entrypoint.sh && \
    echo 'echo "📦 Image: bilal2912/comfyui-flux-kontext:hybrid"' >> /entrypoint.sh && \
    echo 'echo "🧩 Custom nodes: Embedded and ready!"' >> /entrypoint.sh && \
    echo 'echo "📂 Models: Loading from network volume..."' >> /entrypoint.sh && \
    echo 'echo "⚡ Expected startup: 45-90 seconds"' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Show embedded custom nodes status' >> /entrypoint.sh && \
    echo 'echo "🧩 Embedded Custom Nodes Status:"' >> /entrypoint.sh && \
    echo 'if [ -d "/comfyui/custom_nodes/ComfyUI-Easy-Use" ]; then' >> /entrypoint.sh && \
    echo '    echo "  ✅ ComfyUI-Easy-Use: Ready"' >> /entrypoint.sh && \
    echo 'else' >> /entrypoint.sh && \
    echo '    echo "  ❌ ComfyUI-Easy-Use: Missing"' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'if [ -d "/comfyui/custom_nodes/rgthree-comfy" ]; then' >> /entrypoint.sh && \
    echo '    echo "  ✅ rgthree-comfy: Ready"' >> /entrypoint.sh && \
    echo 'else' >> /entrypoint.sh && \
    echo '    echo "  ❌ rgthree-comfy: Missing"' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'if [ -d "/comfyui/custom_nodes/ComfyUI_essentials" ]; then' >> /entrypoint.sh && \
    echo '    echo "  ✅ ComfyUI_essentials: Ready"' >> /entrypoint.sh && \
    echo 'else' >> /entrypoint.sh && \
    echo '    echo "  ❌ ComfyUI_essentials: Missing"' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Setup models from network volume' >> /entrypoint.sh && \
    echo '/setup_models.sh' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo 'echo "🎯 Starting ComfyUI server..."' >> /entrypoint.sh && \
    echo 'echo "🌐 Ready for FLUX Kontext workflows!"' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Start the original ComfyUI process' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Clean up build cache to reduce image size
RUN pip cache purge && \
    apt-get autoremove -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /root/.cache

# Set proper permissions
RUN chmod -R 755 /comfyui && \
    chown -R root:root /comfyui

# Add metadata labels
LABEL maintainer="bilal2912" \
      description="Hybrid Flux Kontext ComfyUI: Custom nodes embedded + Models from network volume" \
      version="1.0" \
      type="hybrid" \
      custom_nodes="embedded" \
      models="network_volume"

# Use the hybrid entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Keep the original CMD from base image
CMD ["/start.sh"]