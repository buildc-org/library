source /ctx/lib/fetch-helpers.sh

fetch_extract "$ASSET_BUILDC_URL" "$ASSET_BUILDC_SHA256" /tmp/tect
install -D -m755 /tmp/tect/tect /usr/bin/tect

mkdir -p /usr/share/buildc
rm -rf /usr/share/buildc/assets
mv /tmp/tect/assets /usr/share/buildc/assets
rm -rf /tmp/tect
