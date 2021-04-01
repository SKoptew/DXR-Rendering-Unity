struct RayPayload
{
    float3 color;
    float3 positionWS;
    uint   bounceIndex;
};

struct ShadowRayPayload
{
    float shadowValue;
};