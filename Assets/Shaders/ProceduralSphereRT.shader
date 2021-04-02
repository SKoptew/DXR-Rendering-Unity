Shader "RT/ProceduralSphere"
{
    Properties
    {
        _Color ("Main color", Color)           = (1,1,1,1)
        _Radius("Radius",     Range(0.01,1.0)) = 0.5
        [Toggle(WORLD_SPACE_CALC)] _WScalc ("World-space calc", Float) = 0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderQueue" = "Geometry"
        }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM
            #pragma vertex   VertForward
            #pragma fragment FragForward
            #include "ProceduralSphereRT_pass_forward.cginc"
            ENDCG
        }
        
        Pass
        {
            Name "RTPass"
            Tags { "LightMode" = "RayTracing"}
            
            HLSLPROGRAM
            #pragma raytracing test
            #pragma multi_compile_local __ RAY_TRACING_PROCEDURAL_GEOMETRY
            #pragma shader_feature WORLD_SPACE_CALC
            #include "ProceduralSphereRT_pass_raytracing.cginc"
            ENDHLSL            
        }
    }
}
