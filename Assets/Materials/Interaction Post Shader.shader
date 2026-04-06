Shader "InteractionPostShader"{
	Properties{
		_MainTex("Main Texture", 2D) = "white"{}
	}
	 
	SubShader{
		Tags{"RenderType" = "Opaque"}
		Pass{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _InteractionGrassLastRT;
			float _DampingSpeed;
			float2 _UVOffset;

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v){
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}

			half4 frag(v2f i) : SV_Target{
				half4 col_Now = tex2D(_MainTex, i.uv);
				
				// 蹇呴』鏄?+ _UVOffset锛屽惁鍒欐嫋灏炬柟鍚戝氨鏄弽鐨?
				half4 col_Last = tex2D(_InteractionGrassLastRT, i.uv + _UVOffset);
                
				// 浠呭鍘嗗彶甯х殑寮哄害 (Alpha) 杩涜娑堟暎
				float alpha_Last = saturate(col_Last.a - _DampingSpeed);
                
				// 姣旇緝寮哄害锛岃皝寮哄氨瀹屽叏閲囩敤璋佺殑鏂瑰悕
				return col_Now.a > alpha_Last ? col_Now : half4(col_Last.rgb, alpha_Last);
			}			
			ENDCG
		}
	}
}
