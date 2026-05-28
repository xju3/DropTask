#!/bin/bash
echo "🔍 开始自动修复和诊断 Xcode 项目..."

# 1. 清理当前目录及子目录下的所有的 xcuserdata
echo "⏳ 1. 正在清理损坏的用户界面状态 (xcuserdata)..."
find . -name "xcuserdata" -type d -exec rm -rf {} +
echo "✅ 用户状态清理完成。"

# 2. 清理 DerivedData
echo "⏳ 2. 正在清理 Xcode Derived Data 缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "✅ 缓存清理完成。"

# 3. 检查 pbxproj 的 mainGroup 是否丢失
echo "⏳ 3. 正在检查 project.pbxproj 核心结构..."
PROJECT_FILE=$(find . -maxdepth 2 -name "project.pbxproj" | head -n 1)

if [ -n "$PROJECT_FILE" ]; then
    if grep -q "mainGroup" "$PROJECT_FILE"; then
        echo "✅ 项目文件外壳正常 (包含 mainGroup 节点)。"
        echo "🎉 自动修复执行完毕。请彻底关闭 Xcode，然后重新打开你的项目！"
    else
        echo "❌ 致命错误: 在 $PROJECT_FILE 中未找到 mainGroup！"
        echo "   这通常是因为 Git 合并冲突不小心删除了核心节点，导致左侧导航栏完全空白。"
        echo "   👉 解决方法: 请在终端执行 'git checkout -- $PROJECT_FILE' 来还原项目文件，或者手动修复代码冲突。"
    fi
else
    echo "⚠️ 警告: 未能在当前目录找到 project.pbxproj 文件。请确认你当前终端处于 Xcode 项目的根目录下！"
fi

