source /ctx/lib/fetch-helpers.sh

fetch_extract "$ASSET_BUILDC_URL" "$ASSET_BUILDC_SHA256" /tmp/buildc
install -D -m755 /tmp/buildc/buildc /usr/bin/buildc

mkdir -p /usr/share/buildc
rm -rf /usr/share/buildc/assets
mv /tmp/buildc/assets /usr/share/buildc/assets
rm -rf /tmp/buildc
