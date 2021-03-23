using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class RayTracingEffect : MonoBehaviour
{
    public LayerMask        rtLayerMask = -1;
    public RayTracingAccelerationStructure.RayTracingModeMask rtModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything;
    public RayTracingShader rtShader;
  //public Light            dirLight;
  //public Cubemap          envMap;

    private RenderTexture                   _rtTargetTexture;
    private RayTracingAccelerationStructure _rtAccStructure;

    private int _cameraWidth, 
                _cameraHeight;

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
        if (!CheckResources())
        {
            Graphics.Blit(src, dest);
            return;
        }

        rtShader.SetShaderPass("RTPass");
        
        //rtShader.SetVector...
        
        //rtShader.SetAccelerationStructure
    }

    private void PrepareResources()
    {
        BuildAccelerationStructure();

        if (_cameraWidth != Camera.main.pixelWidth || _cameraHeight != Camera.main.pixelHeight)
        {
            _cameraWidth  = Camera.main.pixelWidth;
            _cameraHeight = Camera.main.pixelHeight;
            
            _rtTargetTexture = new RenderTexture(_cameraWidth, _cameraHeight, 0, RenderTextureFormat.ARGBHalf);
            _rtTargetTexture.enableRandomWrite = true;
            _rtTargetTexture.Create();
        }
    }

    private void BuildAccelerationStructure()
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

    private bool CheckResources()
    {
        if (!SystemInfo.supportsRayTracing)
        {
            Debug.Log("The RayTracing API isn't supported");
            return false;
        }
        
        if (rtShader == null || _rtAccStructure == null)
            return false;

        return true;
    }
}
