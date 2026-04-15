#!/bin/bash
set -e

CRACKED_IMAGE="$1"
DIFF_FILE="$2"
OUTPUT_DIR="$3"

# 创建临时容器
CONTAINER_ID=$(docker create "$CRACKED_IMAGE")

# 解析 diff 输出，提取文件路径
# container-diff 输出格式示例：
#   --- /some/path
#   +++ /some/path
# 或
#   A  /new/file
#   D  /deleted/file
grep -E '^(---|\+\+\+|A  |D  )' "$DIFF_FILE" | awk '{print $2}' | sort -u | while read -r file; do
    # 跳过空行
    [ -z "$file" ] && continue
    # 跳过目录（以/结尾）
    if [[ "$file" == */ ]]; then
        continue
    fi
    # 确保文件在容器中存在且不是符号链接（可选）
    mkdir -p "$OUTPUT_DIR/$(dirname "$file")"
    if docker cp "$CONTAINER_ID:$file" "$OUTPUT_DIR/$file" 2>/dev/null; then
        echo "Extracted: $file"
    else
        echo "Failed to extract: $file (may not exist or is a directory)"
    fi
done

# 清理容器
docker rm "$CONTAINER_ID"
