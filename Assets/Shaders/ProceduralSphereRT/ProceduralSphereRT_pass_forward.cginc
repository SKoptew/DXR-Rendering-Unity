#include "UnityCG.cginc"

struct appdata
{
    float4 positionOS : POSITION;
};

struct v2f
{
    float4 positionCS : SV_POSITION;            
};

float4 _Color;

v2f VertForward (appdata v)
{
    v2f o;
    o.positionCS = UnityObjectToClipPos(v.positionOS);
    return o;
}

half4 FragForward (v2f i) : SV_Target
{                
    return _Color;
}