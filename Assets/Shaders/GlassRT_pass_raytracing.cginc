#include "UnityShaderVariables.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityRaytracingMeshUtils.cginc"
#include "RayPayload.hlsl"

RaytracingAccelerationStructure _SceneAccelerationStructure;

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
float     _Metalness;
float     _Smoothness;
float     _IOR;
float     _SpecularPower;
int       _MaxBounces;


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

//-- probability of reflection
float SchlickApproximation(float ior, float cosPhi)
{
    float R0 = (1.0-ior)/(1.0+ior);
    R0 *= R0;

    return R0 + (1.0 - R0)*pow(1.0 - cosPhi, 5.0);
}

float Fresnel(float3 I, float3 N, float ior)
{
    float cosi = clamp(-1.0, 1.0, dot(I, N));
    float etai = 1, etat = ior;
    if (cosi > 0) 
    { 
        float temp = etai;
        etai = etat;
        etat = temp;
    }
    
    // Compute sini using Snell's law
    float sint = etai / etat * sqrt(max(0.f, 1 - cosi * cosi));
    
    // Total internal reflection
    if (sint >= 1)
        return 1.0;

    float cost = sqrt(max(0, 1 - sint * sint));
    cosi = abs(cosi);
    float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
    float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
    return (Rs*Rs + Rp*Rp) * 0.5;
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
    float2 uv         =  v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    float4 basecolor  = _MainTex.SampleLevel(sampler_linear_repeat, uv, 0) * _Color;
    
    if (payload.bounceIndex < _MaxBounces)
    {        
        bool isFrontFace = (HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE);

        float3 normalWS = normalize(mul(v.normalOS, (float3x3)WorldToObject()));
        normalWS = isFrontFace ? normalWS : -normalWS;

        float ior = isFrontFace ? (1.0 / _IOR) : _IOR;

        float3 refractedRayWS = refract(WorldRayDirection(), normalWS, ior);
        float3 reflectedRayWS = reflect(WorldRayDirection(), normalWS);


        RayPayload refractedPayload;
        {
            refractedPayload.color = 0;
            refractedPayload.positionWS = 0.0;
            refractedPayload.bounceIndex = payload.bounceIndex + 1;
            
            RayDesc ray;
            ray.Origin    = positionWS;
            ray.Direction = refractedRayWS;
            ray.TMin      = 0.0001f;
            ray.TMax      = 1e20f;
        
            TraceRay(_SceneAccelerationStructure, 0, 0xFF, 0, 1, 0, ray, refractedPayload);
        }
        refractedPayload.color += refractedPayload.color * (basecolor.rgb - 1.0)*basecolor.a;

        RayPayload reflectedRayPayload;
        {
            reflectedRayPayload.color = 0;
            reflectedRayPayload.positionWS = 0.0;
            reflectedRayPayload.bounceIndex = payload.bounceIndex + 1;
        
            RayDesc ray;
            ray.Origin    = positionWS;
            ray.Direction = reflectedRayWS;
            ray.TMin      = 0.0001f;
            ray.TMax      = 1e20f;
        
            TraceRay(_SceneAccelerationStructure, 0, 0xFF, 0, 1, 0, ray, reflectedRayPayload);            
        }
        reflectedRayPayload.color *= basecolor.rgb;

        //float refl = SchlickApproximation(_IOR, dot(normalWS, WorldRayDirection()));
        float refl = Fresnel(WorldRayDirection(), normalWS, _IOR);
        
        payload.color = lerp(refractedPayload.color, reflectedRayPayload.color, refl);

        // direct lighting (and positionWS for shadow calc) for first bounce
        if (payload.bounceIndex == 0)
        {
            float3 lightDirWS = normalize(_WorldSpaceLightPos0.xyz - positionWS);
            payload.color += pow(max(0.0, dot(reflectedRayWS, lightDirWS)), _SpecularPower) * (_LightColor0.rgb * _LightColor0.w) * basecolor;
            payload.positionWS = positionWS;
        }
    }
    else
    {
        payload.color      = basecolor;
        payload.positionWS = positionWS;
    }
}