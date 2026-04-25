docker build --network=host -t whitesscott/pinmux:latest .

docker push whitesscott/pinmux:latest

docker run --rm --runtime=nvidia --name pinmux \
  --ipc=host --cap-add=CAP_SYS_PTRACE --ulimit memlock=-1 --ulimit stack=67108864 \
  -p 8080:80 \
  -v "$HOME/.cache/pinmux-pgdata:/var/lib/postgresql" \
  whitesscott/pinmux:{arm64,amd64} # choose your architecture.

Then open http://localhost:8080
