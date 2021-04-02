#include "UnityShaderVariables.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityRaytracingMeshUtils.cginc"
#include "../RayPayload.hlsl"

struct AttributeData
{
    float2 barycentrics;
};

struct Vertex
{
    float3 positionOS;
    float3 normalOS;
    float2 uv;
};

Texture2D _MainTex;
SamplerState sampler_linear_repeat;
float4    _MainTex_ST;
float4    _Color;

Vertex FetchVertex(uint vertexIndex)
{
    Vertex v;
    v.positionOS = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
    v.normalOS   = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
    v.uv         = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
    
    return v;
}

Vertex InterpolateVertices(Vertex v0, Vertex v1, Vertex v2, float3 barycentrics)
{
    Vertex v;
    #define INTERPOLATE_ATTR(attr) v.attr = v0.attr * barycentrics.x + v1.attr * barycentrics.y + v2.attr * barycentrics.z
    INTERPOLATE_ATTR(positionOS);
    INTERPOLATE_ATTR(normalOS);
    INTERPOLATE_ATTR(uv);
    #undef INTERPOLATE_ATTR

    return v;
}

[shader("closesthit")]
void ClosestHitMain(inout RayPayload payload, AttributeData attribs : SV_IntersectionAttributes)
{
    uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());

    Vertex v0, v1, v2;
    v0 = FetchVertex(triangleIndices.x);
    v1 = FetchVertex(triangleIndices.y);
    v2 = FetchVertex(triangleIndices.z);
       
    float3 barycentricCoords = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y,
                                      attribs.barycentrics.x,
                                      attribs.barycentrics.y);
    
    Vertex v = InterpolateVertices(v0, v1, v2, barycentricCoords);
    //----------------------------------------------------------------------------

    float3 positionWS = mul(ObjectToWorld(), float4(v.positionOS, 1.0));
    float3 normalWS = normalize(mul(v.normalOS, (float3x3)WorldToObject()));
    normalWS = (HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE) ? normalWS : -normalWS;

    float2 uv =  v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    float4 basecolor = _MainTex.SampleLevel(sampler_linear_repeat, uv, 0) * _Color;
    

    float attenuation = saturate(dot(_WorldSpaceLightPos0.xyz, normalWS));
    float3 col = basecolor.rgb * _LightColor0.rgb * _LightColor0.w * attenuation;

    payload.color      = float4(col, basecolor.a);
    payload.positionWS = float4(positionWS, 1.0);
}