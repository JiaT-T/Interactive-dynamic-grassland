Shader "Toon" {
    Properties {
        _MainTex("Main Tex", 2D) = "white"{}
        _Color("Color", Color) = (1,1,1,1)
        _Ramp("Ramp Tex", 2D) = "white"{}
        _Outline("Outline", Range(0, 1)) = 0.1
        _OutlineColor("Outline Color", Color) = (0,0,0,1)
        _Specular("Specular", Color) = (1,1,1,1)
        _SpecularScale("Specular Scale", Range(0,0.1)) = 0.01
    }

    SubShader {
        Pass {
            NAME "OUTLINE"
            Cull Front
            
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag

            float _Outline;
            fixed4 _OutlineColor;

            struct v2f {
                float4 pos : SV_POSITION;
            };

            v2f vert(appdata_full v) {
                v2f o;
                float4 pos = mul(UNITY_MATRIX_MV, v.vertex);
                float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                normal.z = -0.5;
                pos = pos + float4(normalize(normal), 0) * _Outline;
                o.pos = UnityViewToClipPos(pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                return fixed4(_OutlineColor.rgb, 1.0);
            }
            ENDCG
        }

        Pass {
            Tags {"RenderType" = "Opaque" "LightMode" = "ForwardBase" }
            Cull Back
            
            CGPROGRAM
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            sampler2D _Ramp;
            fixed4 _Specular;
            float _SpecularScale;

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            v2f vert(appdata_full v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 worldHalfDir = normalize(worldViewDir + worldLightDir);

                fixed4 c = tex2D(_MainTex, i.uv);
                fixed3 albedo = c.rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
               
                fixed diff = dot(worldNormal, worldLightDir);
                diff = (diff * 0.5 + 0.5) * atten; 
                fixed3 ramp = tex2D(_Ramp, float2(diff, diff)).rgb;
                fixed3 diffuse = _LightColor0.rgb * albedo * ramp * atten;

                float spec = dot(worldNormal, worldHalfDir);
                fixed w = fwidth(spec) * 2.0;
                fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);

                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
