#!/usr/bin/env bash
set -euo pipefail

/usr/bin/swift -e 'import Foundation; DistributedNotificationCenter.default().post(name: Notification.Name("com.jaradjohnson.formatter.format-selection"), object: nil)'
