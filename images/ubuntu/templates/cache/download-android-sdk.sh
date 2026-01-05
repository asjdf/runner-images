#!/bin/bash
# 下载 Android SDK 命令行工具到缓存目录
# 文件名从 toolset.json 中读取，与 install-android-sdk.sh 保持一致
CACHE_DIR="$(dirname "$0")"
TOOLSET_FILE="${CACHE_DIR}/../toolsets/toolset-${VERSION}.json"

# 从 toolset.json 读取文件名
if [ -f "$TOOLSET_FILE" ]; then
    if command -v jq &> /dev/null; then
        FILE_NAME=$(jq -r '.android."cmdline-tools"' "$TOOLSET_FILE")
    elif command -v python3 &> /dev/null; then
        FILE_NAME=$(python3 -c "import json; print(json.load(open('$TOOLSET_FILE'))['android']['cmdline-tools'])")
    else
        # 使用 grep 和 sed 作为后备方案
        FILE_NAME=$(grep -o '"cmdline-tools": "[^"]*"' "$TOOLSET_FILE" | sed 's/.*"cmdline-tools": "\([^"]*\)".*/\1/')
    fi
fi

# 如果无法从 toolset 读取，使用默认值
if [ -z "$FILE_NAME" ] || [ "$FILE_NAME" = "null" ]; then
    echo "警告: 无法从 toolset.json 读取文件名，使用默认值"
    FILE_NAME="commandlinetools-linux-11076708_latest.zip"
fi

FILE_PATH="${CACHE_DIR}/${FILE_NAME}"
URL="https://dl.google.com/android/repository/${FILE_NAME}"

echo "从 toolset.json 读取的文件名: ${FILE_NAME}"

echo "正在下载 Android SDK 命令行工具..."
echo "目标文件: ${FILE_PATH}"

if command -v wget &> /dev/null; then
    wget "${URL}" -O "${FILE_PATH}"
elif command -v curl &> /dev/null; then
    curl -L "${URL}" -o "${FILE_PATH}"
else
    echo "错误: 未找到 wget 或 curl 命令"
    exit 1
fi

if [ -f "${FILE_PATH}" ]; then
    echo "下载完成！文件大小: $(du -h "${FILE_PATH}" | cut -f1)"
    echo "文件位置: ${FILE_PATH}"
else
    echo "错误: 下载失败"
    exit 1
fi
