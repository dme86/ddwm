#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

out_file='./Sources/Common/cmdHelpGenerated.swift'

ddwm_prefix="ddwm"
____usage_prefix="   USAGE:"
_______or_prefix="      OR:"
____strip_prefix="   "

triple_quote='"""'

cat << EOF > $out_file
// FILE IS GENERATED FROM docs/ddwm-*.adoc files
// TO REGENERATE THE FILE RUN ./script/dev.sh generate

EOF

for file in docs/ddwm-*.adoc; do
    subcommand=$(basename "$file" | sed 's/^ddwm-//' | sed 's/\.adoc$//' | sed 's/-/_/g')
    sed -n -E '/tag::synopsis/, /end::synopsis/ p' "$file" | \
        sed '1d' | \
        sed '$d' | \
        sed '/^$/ d' | \
        sed "1   s/^$ddwm_prefix/$____usage_prefix/" | \
        sed "2,$ s/^$ddwm_prefix/$_______or_prefix/" | \
        sed     "s/^$____strip_prefix//" | \
        sed "1 s/^/let ${subcommand}_help_generated = $triple_quote\n/" | \
        sed "\$ s/$/\n${triple_quote}/" | \
        sed '2,$ s/^/    /' >> $out_file
done
