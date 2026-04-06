# Interactive-dynamic-grassland

这是一个基于 Unity 的动态交互草地示例项目，使用几何着色器、细分着色器和渲染纹理来实现草地被角色或摄像机“踩弯”的效果，并叠加风场、阴影和草叶生长形状控制。

## 项目特点

- 使用几何着色器生成草叶，减少手工建模成本。
- 使用细分着色器提高地表草地密度和表现力。
- 通过摄像机生成交互纹理，实现草地受力、恢复和拖尾效果。
- 支持风动、颜色渐变、阴影和草叶弯曲控制。

## 核心文件

- `Assets/Grass.shader`：主草地着色器，负责草叶生成、风动和交互偏移。
- `Assets/Materials/Interaction.cs`：交互控制脚本，挂在摄像机上，负责生成交互纹理。
- `Assets/Materials/Interaction Shader.shader`：交互绘制用着色器，将接触区域写入纹理。
- `Assets/Materials/Interaction Post Shader.shader`：交互后处理着色器，用于衰减和拖尾。
- `Assets/Shaders/CustomTessellation.cginc`：细分着色器公共 include。
- `Assets/Shaders/TessellationExample.shader`：细分着色器示例文件。
- `Assets/Materials/Toon.shader`：卡通风格着色器示例。

## 使用方式

1. 使用支持几何着色器与细分着色器的 Unity 版本打开项目，建议使用与原项目兼容的编辑器版本。
2. 将 `Interaction.cs` 挂到用于交互的摄像机对象上。
3. 在摄像机脚本参数中指定：
   - `Interaction Shader`
   - `Interaction Post Shader`
   - `_InteractionRange`
4. 将 `Assets/Grass.shader` 指定给草地材质，确认材质所需的风图、颜色和交互参数已正确配置。
5. 运行场景后，移动摄像机或交互对象即可看到草地被压弯并逐渐恢复。

## 参数说明

- `_RTScale`：交互范围大小。
- `_DampingSpeed`：交互痕迹衰减速度。
- `_InteractionStrength`：水平推开强度。
- `_InteractionStrengthOfHeight`：草叶高度方向的压低强度。
- `_BladeHeight` / `_BladeWidth` / `_BladeCurve`：草叶外形控制。
- `_WindStrength` / `_WindFrequency`：风动效果控制。

## 参考来源

- Grass Shader 教程思路参考自 Roystan 的草地着色器教程。
- 细分着色器结构参考 Catlike Coding 的 Tessellation 教程。

## 说明

当前仓库主要提供草地渲染与交互的核心脚本、着色器文件，适合作为 Unity 动态草地效果的基础模板继续扩展。
