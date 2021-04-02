#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityLightingCommon.cginc"

struct appdata
{
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float2 uv         : TEXCOORD0;
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float3 normalWS   : TEXCOORD1;
    float2 uv         : TEXCOORD0;                
};

sampler2D _MainTex;
float4    _MainTex_ST;
float4    _Color;

v2f VertForward (appdata v)
{
    v2f o;
    o.positionCS = UnityObjectToClipPos(v.positionOS);
    o.normalWS   = UnityObjectToWorldNormal(v.normalOS);
    o.uv         = TRANSFORM_TEX(v.uv, _MainTex);
    return o;
}

half4 FragForward (v2f i) : SV_Target
{
    float4 basecolor = tex2D(_MainTex, i.uv) * _Color;
    float attenuation = saturate(dot(_WorldSpaceLightPos0.xyz, i.normalWS));
    float3 col = basecolor.rgb * _LightColor0.rgb * _LightColor0.w * attenuation;
                
    return float4(col, basecolor.a);
}