#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
verification_dir=$(mktemp -d /private/tmp/omamori-check.XXXXXX)
trap 'rm -rf "$verification_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$verification_dir/cache" -o "$verification_dir/verify" OmamoriApp/Models/Models.swift OmamoriApp/Models/CollectionSelection.swift OmamoriApp/Services/FirebaseService.swift OmamoriApp/Services/AppStore.swift Scripts/VerifyCore.swift
"$verification_dir/verify"
