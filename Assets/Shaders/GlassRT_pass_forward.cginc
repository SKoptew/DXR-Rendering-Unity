#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityPBSLighting.cginc"

struct appdata
{
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float2 uv         : TEXCOORD0;
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float4 positionWS : TEXCOORD0;
    float3 normalWS   : TEXCOORD1;
    float2 uv         : TEXCOORD2;                
};

sampler2D _MainTex;
float4    _MainTex_ST;
float4    _Color;
float     _Metalness;
float     _Smoothness;

v2f VertForward (appdata v)
{
    v2f o;
    o.positionCS = UnityObjectToClipPos(v.positionOS);
    o.positionWS = mul(unity_ObjectToWorld, v.positionOS);
    o.normalWS   = UnityObjectToWorldNormal(v.normalOS);
    o.uv         = TRANSFORM_TEX(v.uv, _MainTex);
    return o;
}

half4 FragForward (v2f IN) : SV_Target
{
    half3  viewWS        = normalize(_WorldSpaceCameraPos - IN.positionWS.xyz);
    float3 reflectionDir = reflect(-viewWS, IN.normalWS);
    float4 basecolor     = tex2D(_MainTex, IN.uv) * _Color;


    SurfaceOutputStandard surface;
    surface.Albedo     = basecolor.rgb;
    surface.Normal     = IN.normalWS;
    surface.Emission   = 0;
    surface.Metallic   = _Metalness;
    surface.Smoothness = _Smoothness;
    surface.Occlusion  = 0.0;
    surface.Alpha      = basecolor.a;

    Unity_GlossyEnvironmentData env_data;
    env_data.roughness = 1 - surface.Smoothness;
    env_data.reflUVW   = BoxProjectedCubemapDirection(reflectionDir, IN.positionWS.xyz, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);

    UnityGI gi;
    gi.light.color = _LightColor0.rgb;
    gi.light.dir   = _WorldSpaceLightPos0.xyz;
    gi.indirect.diffuse  = ShadeSHPerPixel(IN.normalWS, unity_AmbientSky, IN.positionWS);
    gi.indirect.specular = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, env_data);

    float4 col = LightingStandard(surface, viewWS, gi);
                
    return col;
}