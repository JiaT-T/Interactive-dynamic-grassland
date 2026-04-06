Shader "Interaction" {
	Properties {
		_InteractionRange ("Interaction Range", Float) = 0.5
	}

	SubShader {
		Tags { "RenderType"="Opaque" }
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			float _InteractionRange;

			struct v2f {
				float4 pos : SV_POSITION;
				float2 pushDirXZ : TEXCOORD0; // 世界空间推力方向
				float localDist : TEXCOORD1;  // 模型局部距离
			};

			v2f vert (appdata_base v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 获取物体局部的向外方向，并转换到世界空间
				float3 objDir = float3(v.vertex.x, 0, v.vertex.z);
				o.pushDirXZ = mul((float3x3)unity_ObjectToWorld, objDir).xz;
				
				// 计算距离用于衰减
				o.localDist = length(v.vertex.xz);
				return o;
			}
			
			half4 frag (v2f i) : SV_Target {
				float dist = length(i.pushDirXZ);
				float2 dir = dist > 0.001 ? (i.pushDirXZ / dist) : float2(0,0);
				
				// 映射向量从 [-1, 1] 到 [0, 1] 存入颜色通道
				dir = dir * 0.5 + 0.5;

				// 根据距离计算中心强、边缘弱的平滑衰减。_InteractionRange(即C#中的_Domain)用作缩放因子
				float damping = 1.0 - saturate(i.localDist / max(_InteractionRange, 0.01));
				damping *= damping; 

				return half4(dir.x, dir.y, 0, saturate(damping));
			}
			ENDCG
		}
	}
}
