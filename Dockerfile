FROM python:3.10-slim

# Install inotify-tools to monitor folder changes
RUN apt-get update && apt-get install -y inotify-tools git \
    && apt-get install -y python3 p7zip-full python3-pil python3-psutil python3-slugify

WORKDIR /usr/src/kombo

RUN git clone https://github.com/soda3x/kcc.git

RUN pip install --no-cache-dir -r kcc/requirements.txt

# Create directories for input and output folders inside the container
RUN mkdir /input /output

COPY monitor.sh .

# Convert Windows line endings to Unix and make executable
RUN sed -i 's/\r$//' monitor.sh && chmod +x monitor.sh

# Run the monitor script when the container starts
CMD ["/usr/src/kombo/monitor.sh"]