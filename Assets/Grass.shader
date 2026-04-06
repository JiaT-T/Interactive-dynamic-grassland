Shader "Roystan/Grass With Interaction"
{
    Properties
    {
        [Header(Shading)]
        _TopColor("Top Color", Color) = (1,1,1,1)
        _BottomColor("Bottom Color", Color) = (1,1,1,1)
        _TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        _BladeWidth("Blade Width", float) = 0.05
        _BladeWidthRandom("Blade Width Random",float) = 0.02
        _BladeHeight("Blade Height", float) = 0.5
        _BladeHeightRandom("Blade Height Random", float) = 0.3
        _BladeForward("Blade Forward Amount", float) = 0.38
        _BladeCurve("Blade Curve",Range(1, 4)) = 2
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
        _WindDistortionMap("Wind Distortion Map", 2D) = "white"{}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0 )
        _WindStrength("Wind Strength", float) = 1
        
        [Header(Interaction)]
        _InteractionStrength("Interaction Strength",Range(0.0, 50.0)) = 1
        _InteractionStrengthOfHeight("Interaction Strength Of Height", Range(0.0, 3.0)) = 1.5
        _GrassInteractionTex("Grass Interaction Tex", 2D) = "white"{}
    }

    CGINCLUDE
    #include "UnityCG.cginc"
    #include "Autolight.cginc"
    #include "Shaders/CustomTessellation.cginc"

    #define BLADE_SEGMENTS 3

    float _BendRotationRandom;
    float _BladeWidth;
    float _BladeWidthRandom;
    float _BladeHeight;
    float _BladeHeightRandom;
    float _BladeForward;
    float _BladeCurve;
    sampler2D _WindDistortionMap;
    float4 _WindDistortionMap_ST;
    float2 _WindFrequency;
    float _WindStrength;
    
    // 交互属性
    float3 _InteractionCamPos;
    float _InteractionCamSize;
    sampler2D _GrassInteractionTex;
    float _InteractionStrength;
    float _InteractionStrengthOfHeight;

    // 随机函数
    float rand(float3 co) {
        return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
    }

    // 角度-轴旋转矩阵
    float3x3 AngleAxis3x3(float angle, float3 axis) {
        float c, s;
        sincos(angle, s, c);
        float t = 1 - c;
        float x = axis.x;
        float y = axis.y;
        float z = axis.z;

        return float3x3(
            t*x*x + c, t*x*y - s*z, t*x*z + s*y,
            t*x*y + s*z, t*y*y + c, t*y*z - s*x,
            t*x*z - s*y, t*y*z + s*x, t*z*z + c
        );
    }

    vertexOutput vert(float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT) {
        vertexOutput o;
        o.vertex = vertex;
        o.normal = normal;
        o.tangent = tangent;
        return o;
    }

    struct geometryOutput {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
        unityShadowCoord4 _ShadowCoord : TEXCOORD1;
    };

    geometryOutput VertexOutput(float3 pos, float2 uv, float3 normal) {
        geometryOutput o;
        o.pos = UnityObjectToClipPos(pos);
        o.uv = uv;
        o.normal = UnityObjectToWorldNormal(normal);
        o._ShadowCoord = ComputeScreenPos(o.pos);
        
        #if UNITY_PASS_SHADOWCASTER
            o.pos = UnityApplyLinearShadowBias(o.pos);
        #endif

        return o;
    }

    // 修改后的 GenerateGrassVertex 函数，包含交互偏移
    geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrix, float3 interactionOffset, float segmentHeight) {
        float3 tangentPoint = float3(width, forward, height);
        float3 tangentNormal = normalize(float3(0, -1, forward));
        float3 localNormal = mul(transformMatrix, tangentNormal);
        
        // 应用交互偏移到顶点位置
        float3 localPosition = mul(transformMatrix, tangentPoint) + vertexPosition;
        
        // 交互效果应用
        localPosition.xz += interactionOffset.xy * segmentHeight * _InteractionStrength;
        localPosition.y = saturate(localPosition.y - interactionOffset.z * segmentHeight * _InteractionStrengthOfHeight);

        return VertexOutput(localPosition, uv, localNormal);
    }

    // 计算交互偏移
    float3 CalculateInteractionOffset(float3 worldPos) {
        // 使用包围盒映射，绝对不会因为 Matrix 的底层 API 差异产生 Y 轴翻转
        float2 interactionUV = (worldPos.xz - _InteractionCamPos.xz) / (_InteractionCamSize * 2.0) + 0.5;
        
        // UV 越界保护，不在相机范围内的草不产生计算
        if(interactionUV.x < 0 || interactionUV.x > 1 || interactionUV.y < 0 || interactionUV.y > 1) 
            return float3(0,0,0);

        float4 interactionData = tex2Dlod(_GrassInteractionTex, float4(interactionUV, 0, 0));
        
        // 还原向外推开的真实物理向量
        float3 offset = float3(
            (interactionData.r * 2.0 - 1.0) * interactionData.a,  
            (interactionData.g * 2.0 - 1.0) * interactionData.a,  
            interactionData.a                                
        );
        return offset;
    }

    [maxvertexcount(BLADE_SEGMENTS * 2 - 1)]
    void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream) {
        float3 pos = IN[0].vertex;

        float3 vNormal = IN[0].normal;
        float4 vTangent = IN[0].tangent;
        float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

        // 计算世界空间位置用于交互
        float3 worldPos = mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz;
        float3 interactionOffset = CalculateInteractionOffset(worldPos);

        // 构造TBN矩阵
        float3x3 TBN_Matrix = float3x3(
            vTangent.x, vBinormal.x, vNormal.x,
            vTangent.y, vBinormal.y, vNormal.y,
            vTangent.z, vBinormal.z, vNormal.z
        );
        
        // 各种旋转矩阵
        float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0,0,1));
        float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));
        
        float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
        float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
        float3 wind = normalize(float3(windSample.xy,0));
        float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);
        
        float3x3 transformationMatrix = mul(mul(mul(TBN_Matrix, windRotation), facingRotationMatrix), bendRotationMatrix);
        float3x3 transformationMatrixFacing = mul(TBN_Matrix, facingRotationMatrix);

        // 随机高度与宽度
        float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
        float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
        float forward = rand(pos.yyz) * _BladeForward;

        // 生成草叶几何
        for(int i = 0; i < BLADE_SEGMENTS; i++) {
            float t = i / (float)BLADE_SEGMENTS;
            float segmentHeight = height * t;
            float segmentWidth = width * (1 - t);
            float segmentForward = pow(t, _BladeCurve) * forward;

            float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

            // 生成左右顶点，传入交互偏移和段高度
            triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix, interactionOffset, segmentHeight));
            triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix, interactionOffset, segmentHeight));
        }
        
        // 生成顶部顶点
        triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix, interactionOffset, height));
    }
    ENDCG

    SubShader
    {
        Cull Off

        Pass
        {
            Tags
            {
                "RenderType" = "Opaque"
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag
            #pragma target 5.0
            #pragma hull hull
            #pragma domain domain
            #pragma multi_compile_fwdbase

            #include "Lighting.cginc"
            
            float4 _TopColor;
            float4 _BottomColor;
            float _TranslucentGain;
                
            float4 frag (geometryOutput i, fixed facing : VFACE) : SV_Target
            {    
                float3 normal = facing > 0 ? i.normal : -i.normal;
                float shadow = SHADOW_ATTENUATION(i);
                float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;
                float3 ambient = ShadeSH9(float4(normal, 1));
                float4 lightIntensity = NdotL * _LightColor0 + float4(ambient, 1);
                float4 col = lerp(_BottomColor, _TopColor * lightIntensity, i.uv.y);

                return col;
            }
            ENDCG
        }
        Pass
        {
            Tags{ "LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag
            #pragma target 5.0
            #pragma hull hull
            #pragma domain domain
            #pragma multi_compile_shadowcaster

            float4 frag(geometryOutput i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}
