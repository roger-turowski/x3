# Install Ollama natively
sudo curl -fsSL https://ollama.com/install.sh | sh

# Enable and start the service
sudo systemctl enable ollama

# Open firewall if needed
sudo firewall-cmd --permanent --add-port=11434/tcp
sudo firewall-cmd --reload

# Create the ollama service
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_MODELS=/data/llm/ollama/.ollama/models"
Environmeny="OLLAMA_KEEP_ALIVE=30m"
EOF

sudo mkdir -p /data/llm/{models,huggingface,ollama/.ollama/models/blobs,ollama/.ollama/models/manifests}
sudo chown -R ollama:ollama /data/llm/ollama

# Sync any existing models to data location
sudo rsync -aP /usr/share/ollama/.ollama/ /data/llm/ollama/.ollama

# sudo systemctl edit ollama
sudo systemctl daemon-reload
sudo systemctl start ollama

# Test the installation
# ollama list
# sudo rm -rf /usr/share/ollama/.ollama

