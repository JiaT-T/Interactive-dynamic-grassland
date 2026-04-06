using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Interaction : MonoBehaviour
{
    public Shader InteractionShader;
    private Camera _camera;
    private RenderTexture _RT = null;
    private RenderTexture _LastRT = null;

    public Transform _InteractionRange;
    [Range(0.0f, 50.0f)]
    public float _RTScale = 3f;
    [Range(0.000f, 0.100f)]
    public float _Domain = 0.3f;
    [Range(0.0065f, 0.1000f)]
    public float _DampingSpeed = 0.01f;

    public Shader InteractionPostShader;
    private Material InteractionGrassPostMaterial;

    // 优化的 Shader ID
    private int GrassInteractionTexID;
    private int InteractionCamPosID;
    private int InteractionCamSizeID;
    private int InteractionGrassLastRTID;
    private int DampingSpeedID;
    private int UVOffsetID;

    private Vector3 _lastCamPos;

    void Start()
    {
        _camera = gameObject.GetComponent<Camera>();

        GrassInteractionTexID = Shader.PropertyToID("_GrassInteractionTex");
        InteractionCamPosID = Shader.PropertyToID("_InteractionCamPos");
        InteractionCamSizeID = Shader.PropertyToID("_InteractionCamSize");
        InteractionGrassLastRTID = Shader.PropertyToID("_InteractionGrassLastRT");
        DampingSpeedID = Shader.PropertyToID("_DampingSpeed");
        UVOffsetID = Shader.PropertyToID("_UVOffset");

        InteractionGrassPostMaterial = new Material(InteractionPostShader);

        // 统一格式，确保支持负值/精度
        _RT = new RenderTexture(1024, 1024, 0, RenderTextureFormat.ARGB32);
        _RT.wrapMode = TextureWrapMode.Clamp;
        _RT.hideFlags = HideFlags.DontSave;

        _LastRT = new RenderTexture(1024, 1024, 0, RenderTextureFormat.ARGB32);
        _LastRT.wrapMode = TextureWrapMode.Clamp;
        _LastRT.hideFlags = HideFlags.DontSave;

        _camera.targetTexture = _RT;
        _camera.SetReplacementShader(InteractionShader, "RenderType");
        _camera.aspect = 1.0f;

        _lastCamPos = _camera.transform.position;
    }

    void Update()
    {
        _InteractionRange.localScale = new Vector3(_RTScale, _RTScale, _RTScale);
        _camera.orthographicSize = _RTScale;

        // 全局传递基础参数，抛弃不稳定的矩阵变换
        Shader.SetGlobalVector(InteractionCamPosID, _camera.transform.position);
        Shader.SetGlobalFloat(InteractionCamSizeID, _RTScale);
        Shader.SetGlobalTexture(GrassInteractionTexID, _LastRT); // 草地直接采样混合好的 _LastRT
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (InteractionGrassPostMaterial != null)
        {
            Vector3 currentPos = _camera.transform.position;
            Vector3 delta = currentPos - _lastCamPos;

            // 计算相机 UV 位移量 (位移 / 画面尺寸)
            Vector2 uvOffset = new Vector2(delta.x, delta.z) / (_RTScale * 2f);

            InteractionGrassPostMaterial.SetVector(UVOffsetID, uvOffset);
            InteractionGrassPostMaterial.SetTexture(InteractionGrassLastRTID, _LastRT);
            InteractionGrassPostMaterial.SetFloat(DampingSpeedID, _DampingSpeed);

            // 使用临时 RT 避免同源读写冲突！
            RenderTexture tempRT = RenderTexture.GetTemporary(_RT.width, _RT.height, 0, _RT.format);
            Graphics.Blit(_RT, tempRT, InteractionGrassPostMaterial);
            Graphics.Blit(tempRT, _LastRT); // 安全地将混合结果写回 LastRT
            RenderTexture.ReleaseTemporary(tempRT);

            Graphics.Blit(_LastRT, dest);

            _lastCamPos = currentPos;
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
