case ":${PATH}:" in
    *:/usr/local/cuda/bin:*) ;;
    *) PATH="${PATH}:/usr/local/cuda/bin" ;;
esac
