struct RayPayload
{
    float3 color;
    float4 positionWS;  // .a : 1.0 for geometry hit, 0.0 for miss shader. used for shadowcasting
    uint   bounceIndex;
};

struct ShadowRayPayload
{
    float shadowValue;
};