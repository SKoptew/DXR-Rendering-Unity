using UnityEngine;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class RayTracingEffect : MonoBehaviour
{
    public LayerMask        rtLayerMask = -1;
    public RayTracingAccelerationStructure.RayTracingModeMask rtModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything;
    public RayTracingShader rtShader;
    public Cubemap          environmentCubemap;
    
    [Range(0,8)] public float environmentExposure = 1f;
    [Range(0,1)] public float shadowBrightness    = 0.15f;

    public float tMin = 0.001f;
    public float tMax = 1000f;

    private RenderTexture                   _rtTargetTexture;
    private RayTracingAccelerationStructure _rtAccStructure;

    private int _cameraWidth, 
                _cameraHeight;

    private static class ShaderID
    {
        //-- global
        public static readonly int _T_minmax = Shader.PropertyToID("_T_minmax");

        //-- local
        public static readonly int _SceneAccelerationStructure = Shader.PropertyToID("_SceneAccelerationStructure");
        public static readonly int _RenderTarget               = Shader.PropertyToID("_RenderTarget");
        public static readonly int _EnvironmentTex             = Shader.PropertyToID("_EnvironmentTex");
        public static readonly int _EnvironmentGamma           = Shader.PropertyToID("_EnvironmentExposure");
        public static readonly int _ShadowBrightness           = Shader.PropertyToID("_ShadowBrightness");
        public static readonly int _InvViewMatrix              = Shader.PropertyToID("_InvViewMatrix");
        public static readonly int _FrustumBottomLeftDirWS     = Shader.PropertyToID("_FrustumBottomLeftDirWS");
        public static readonly int _FrustumHorizDirWS          = Shader.PropertyToID("_FrustumHorizDirWS");
        public static readonly int _FrustumVertDirWS           = Shader.PropertyToID("_FrustumVertDirWS");
    }
    

    public void Update()
    {
        PrepareResources();
    }

    public void OnDisable()
    {
        DestroyResources();
    }

    public void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var cam = Camera.main;
        
        if (!CheckResources(cam))
        {
            Graphics.Blit(src, dest);
            return;
        }

        //-- shader pass "RTPass" in material shaders
        rtShader.SetShaderPass("RTPass");
        
        //- set global variables, used in all material shaders
        Shader.SetGlobalVector(ShaderID._T_minmax,  new Vector2(tMin, tMax));
        
        //-- set local RT raygen shader variables
        _rtAccStructure.Build();
        rtShader.SetAccelerationStructure(ShaderID._SceneAccelerationStructure, _rtAccStructure);
        
        rtShader.SetTexture(ShaderID._RenderTarget,  _rtTargetTexture);
        rtShader.SetMatrix( ShaderID._InvViewMatrix, cam.cameraToWorldMatrix);
        rtShader.SetTexture(ShaderID._EnvironmentTex, environmentCubemap);
        rtShader.SetFloat  (ShaderID._EnvironmentGamma, Mathf.GammaToLinearSpace(environmentExposure));
        rtShader.SetFloat  (ShaderID._ShadowBrightness, shadowBrightness);

        var camOrigin = cam.transform.position;
        var frustumBottomLeftDirWS  = (cam.ViewportToWorldPoint(new Vector3(0, 0, cam.nearClipPlane)) - camOrigin).normalized;
        var frustumBottomRightDirWS = (cam.ViewportToWorldPoint(new Vector3(1, 0, cam.nearClipPlane)) - camOrigin).normalized;
        var frustumTopLeftDirWS     = (cam.ViewportToWorldPoint(new Vector3(0, 1, cam.nearClipPlane)) - camOrigin).normalized;

        rtShader.SetVector(ShaderID._FrustumBottomLeftDirWS, frustumBottomLeftDirWS);
        rtShader.SetVector(ShaderID._FrustumHorizDirWS, frustumBottomRightDirWS - frustumBottomLeftDirWS);
        rtShader.SetVector(ShaderID._FrustumVertDirWS, frustumTopLeftDirWS - frustumBottomLeftDirWS);

        //-- dispatch ray tracing
        rtShader.Dispatch("RaygenShader", cam.pixelWidth, cam.pixelHeight, 1);
        Graphics.Blit(_rtTargetTexture, dest);
    }

    private void PrepareResources()
    {
        CreateAccelerationStructure();

        if (_rtTargetTexture == null || _cameraWidth != Camera.main.pixelWidth || _cameraHeight != Camera.main.pixelHeight)
        {
            _cameraWidth  = Camera.main.pixelWidth;
            _cameraHeight = Camera.main.pixelHeight;
            
            _rtTargetTexture = new RenderTexture(_cameraWidth, _cameraHeight, 0, RenderTextureFormat.ARGBHalf);
            _rtTargetTexture.enableRandomWrite = true;
            _rtTargetTexture.Create();
        }
    }

    private void CreateAccelerationStructure()
    {
        if (_rtAccStructure == null)
        {
            var settings = new RayTracingAccelerationStructure.RASSettings();
            settings.layerMask          = rtLayerMask;
            settings.managementMode     = RayTracingAccelerationStructure.ManagementMode.Automatic;
            settings.rayTracingModeMask = rtModeMask;

            _rtAccStructure = new RayTracingAccelerationStructure(settings);
        }
    }
    
    private void DestroyResources()
    {
        if (_rtTargetTexture != null)
        {
            _rtTargetTexture.Release();
            _rtTargetTexture = null;
        }

        if (_rtAccStructure != null)
        {
            _rtAccStructure.Release();
            _rtAccStructure = null;
        }
    }

    private bool CheckResources(Camera cam)
    {
        if (!SystemInfo.supportsRayTracing)
        {
            Debug.Log("The RayTracing API isn't supported");
            return false;
        }
        
        if (environmentCubemap == null || cam == null || rtShader == null || _rtAccStructure == null)
            return false;

        return true;
    }
}
