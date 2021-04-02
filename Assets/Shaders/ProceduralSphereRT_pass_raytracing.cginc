#include "UnityShaderVariables.cginc"
#include "UnityLightingCommon.cginc"
#include "RayPayload.hlsl"

float4 _Color;
float  _Radius;

struct AttributeData
{
    float3 normalWS;
};

#if WORLD_SPACE_CALC
//-- World-space ray-sphere intersection
[shader("intersection")]
void ProceduralSphereIntersectionMain()
{
    const float3 Center = ObjectToWorld4x3()[3];

    float3 o = WorldRayOrigin();       // world-space origin    of ray
    float3 d = WorldRayDirection();    // world-space direction of ray
    float3 oc = o - Center;
    
    float  half_B = dot(d,oc);
    float  C      = dot(oc,oc) - _Radius*_Radius;

    float discr = half_B*half_B - C; // 1/4*discriminant

    if (discr >= 0)
    {
        const float root = sqrt(discr);

        float t = -half_B - root;

        if (t < 0.0) // inner surface of sphere
            t = -half_B + root;
               
        float3 hitPositionWS = o + t*d;

        AttributeData attr;
        attr.normalWS = normalize(hitPositionWS - Center);        

        ReportHit(t, 0, attr);
    }
}

#else

//-- Object-space ray-sphere intersection
[shader("intersection")]
void ProceduralSphereIntersectionMain()
{
    float3 o = ObjectRayOrigin();
    float3 d = ObjectRayDirection();
    
    float  b05   = dot(o, d);
    float  c     = dot(o, o) - _Radius*_Radius;
    float  discr = b05*b05 - c;
    
    if (discr >= 0)
    {
        float root = sqrt(discr);

        float t = -b05 - root;
        if (t < 0.0)
            t = -b05 + root;

        float3 hitPosOS = ObjectRayOrigin() + t * ObjectRayDirection();

        AttributeData attr;
        attr.normalWS = normalize( mul(hitPosOS, (float3x3)WorldToObject()));

        float3 hitPosWS = mul(ObjectToWorld(), float4(hitPosOS, 1));

        float THit = length(hitPosWS - WorldRayOrigin());

        ReportHit(THit, 0, attr);
    }
}

#endif

[shader("closesthit")]
void ClosestHitMain(inout RayPayload payload, AttributeData attribs : SV_IntersectionAttributes)
{
    float3 normalWS   = attribs.normalWS;
    float3 positionWS = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
    //----------------------------------------------------------------------------

    float attenuation = saturate(dot(_WorldSpaceLightPos0.xyz, normalWS));
    float3 col = _Color.rgb * _LightColor0.rgb * _LightColor0.w * attenuation;

    payload.color      = float4(col, _Color.a);
    payload.positionWS = float4(positionWS, 1.0);
}

