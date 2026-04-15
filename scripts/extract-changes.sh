#!/bin/bash
set -e

CRACKED_IMAGE="$1"
DIFF_FILE="$2"
OUTPUT_DIR="$3"

echo "Parsing diff file: $DIFF_FILE"

# 创建临时容器
CONTAINER_ID=$(docker create "$CRACKED_IMAGE")
echo "Created container $CONTAINER_ID"

# 提取所有被修改或新增的文件路径
# container-diff 输出示例:
# --- /system/MediaBrowser.Model.dll
# +++ /system/MediaBrowser.Model.dll
# 或者 A  /some/new/file
# 或者 D  /some/deleted/file
grep -E '^(---|\+\+\+|A  |D  )' "$DIFF_FILE" | awk '{print $2}' | sort -u | while read -r filepath; do
    # 去除开头的 / 如果存在
    filepath="${filepath#/}"
    # 跳过空行或目录（如果以 / 结尾）
    if [ -z "$filepath" ] || [[ "$filepath" == */ ]]; then
        continue
    fi
    # 检查容器内是否存在该文件（且为普通文件）
    if docker exec "$CONTAINER_ID" test -f "/$filepath"; then
        mkdir -p "$OUTPUT_DIR/$(dirname "$filepath")"
        if docker cp "$CONTAINER_ID:/$filepath" "$OUTPUT_DIR/$filepath" 2>/dev/null; then
            echo "✓ Extracted: $filepath"
        else
            echo "✗ Failed to copy: $filepath"
        fi
    else
        echo "✗ Not a regular file (or doesn't exist): $filepath"
    fi
done

# 清理容器
docker rm "$CONTAINER_ID"
echo "Done."
