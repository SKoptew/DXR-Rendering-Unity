Shader "RT/Diffuse"
{
    Properties
    {
        _Color  ("Main color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
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
            #include "DiffuseRT_pass_forward.cginc"
            ENDCG
        }
        
        Pass
        {
            Name "RTPass"
            Tags { "LightMode" = "RayTracing"}
            
            HLSLPROGRAM
            #pragma raytracing test
            #include "DiffuseRT_pass_raytracing.cginc"
            ENDHLSL            
        }
    }
}
