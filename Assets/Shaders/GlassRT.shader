Shader "RT/Glass"
{
    Properties
    {
        _Color        ("Color",          Color)         = (1,1,1,1) 
        _MainTex      ("Texture",        2D)            = "white" {}
        _Metalness    ("Metalness",      Range(0,1))    = 1.0
        _Smoothness   ("Smoothness",     Range(0,1))    = 0.5
        _IOR          ("IOR",            Range(1,2))    = 1.4
        _SpecularPower("_SpecularPower", Range(1, 100)) = 40.0
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "Queue"      = "Transparent"
        }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            
            Blend One OneMinusSrcAlpha
            ZWrite Off
            
            CGPROGRAM
            #pragma vertex   VertForward
            #pragma fragment FragForward
            #include "GlassRT_pass_forward.cginc"
            ENDCG
        }
        
        Pass
        {
            name "RTPass"
            Tags { "LightMode" = "RayTracing" }
            
            HLSLPROGRAM
            #pragma raytracing test
            #include "GlassRT_pass_raytracing.cginc"
            ENDHLSL
        }
    }
}
