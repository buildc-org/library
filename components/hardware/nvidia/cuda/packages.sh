REPO_ID="cuda-fedora$(rpm -E %fedora)-x86_64"

toolkit=cuda-toolkit
if [ "$OPT_VERSION" != latest ]; then
    toolkit="cuda-toolkit-${OPT_VERSION//./-}"
fi
dnf5 install -y --enablerepo="$REPO_ID" --setopt=install_weak_deps=False "$toolkit"
