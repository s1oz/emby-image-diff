#!/bin/bash
set -e

CRACKED_IMAGE="$1"
JSON_FILE="$2"
OUTPUT_DIR="$3"

# 创建临时容器
CONTAINER_ID=$(docker create "$CRACKED_IMAGE")

# 解析 JSON，提取所有 Added 和 Modified 文件的路径
# container-diff JSON 格式示例：
# {
#   "Analysis": {
#     "Image1": {...},
#     "Image2": {...},
#     "Diff": {
#       "Files": [
#         {"Path": "/some/file", "Type": "Added"},
#         {"Path": "/another/file", "Type": "Modified"}
#       ]
#     }
#   }
# }
jq -r '.Analysis.Diff.Files[] | select(.Type == "Added" or .Type == "Modified") | .Path' "$JSON_FILE" | while read -r file; do
    if [ -z "$file" ]; then
        continue
    fi
    # 确保目标目录存在
    mkdir -p "$OUTPUT_DIR/$(dirname "$file")"
    # 尝试复制文件（注意 docker cp 需要容器内路径，可以带前导 /）
    if docker cp "$CONTAINER_ID:$file" "$OUTPUT_DIR/$file" 2>/dev/null; then
        echo "Extracted: $file"
    else
        echo "Failed to extract: $file (file may not exist in container or is a directory)"
    fi
done

docker rm "$CONTAINER_ID"
