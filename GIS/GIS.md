# GIS
Geographic Information System

## 各种数据
1. 常见数据
卫片：人造卫星拍摄的影像
航片:飞机拍摄的影像 无人机 有人机

DEM:数字高程模型 可以通过航空摄影 激光雷达 卫星遥感 干涉合成孔径雷达等获得数据
DOM:数字正射影像图 卫片经过校正 以及DEM等获得数据,可以贴在DEM上当做纹理 .tif文件 tiff GeoTiff
DSM:数字表面模型 地物高程模型 地表+地面物体
DTM:数字地形模型 地表高程模型

dem可以生成等高线

拍摄影像 三维点云 构建tin网 构建白模 纹理映射

白模:纯几何结构与拓扑 白模​​（White Model）是指​​仅包含几何结构而不包含任何材质、纹理、贴图或照明的3D模型​​。它通常以单一的白色或灰色显示，专注于模型的​​几何形状​​和​​拓扑结构​​。
def validate_white_model(model):
    checks = {
        'manifold': check_manifold_geometry(model),      # 流形几何
        'non_degenerate': check_non_degenerate_faces(model), # 无退化面
        'normal_consistency': check_normals(model),     # 法线一致性
        'uv_ready': check_uv_readiness(model),          # UV展开就绪
        'polycount_optimal': check_polycount(model)      # 多边形数量优化
    }
    return all(checks.values())

Oblique Photography
倾斜摄影:一正四斜(前后左右) 垂直摄影(卫星遥感 航空正射摄影)

空三:空中三角测量 Aerotriangulation AT 是由摄影测量发展而来的一种测量方法，它通过分析多张影像之间的几何关系，计算出地面点的三维坐标。空中三角测量是三维重建的基础，它可以帮助我们得到稀疏点云，进而得到稠密点云，最后得到三维模型。
地三:地面控制点 Ground Control Point GCP？



多视几何 三维重建
多视角成像 利用视差 计算三维坐标
视差匹配得到深度
深度得到点云

倾斜摄影获取的原始数据是啥?应该就是一系列的png图片，通过空三求解(包括特征提取、特征匹配、光束法平差)得到稀疏点云，再得到稠密点云 泊松重建得到mesh 纹理映射
后处理得到的数据格式可以是osgb obj fbx 3dtiles
点云分割得到DEM DSM DTM

**倾斜摄影得到的原始数据**
1. 多视角影像数据 一个垂直镜头四个倾斜镜头采集的jpg格式的 提供地物多角度的视觉信息，是三维重建的基础
2. 定位定姿数据 由GNSS(全球导航卫星系统global navigation satelite system)和IMU(惯性测量单元)系统记录的每张影像的外方位元素（如X, Y, Z, Omega, Phi, Kappa），通常存储在CSV或XML文件中（如Image.csv），提供影像的空间位置和姿态，用于空中三角测量和精确三维重建
3. 相机参数文件 记录相机的内方位元素（如焦距、像主点）和镜头畸变参数等，通常存储在CSV文件（如Camera.csv）中 用于校正影像畸变，保证几何精度
4. 元数据文件 ​如metadata.xml文件，记录整个数据集的坐标系、插入点坐标、生产信息等 描述数据的空间参考和基本属性，便于后续处理软件正确读取和定位数据
5. 数据组织文件 如OSGB格式数据对应的配置文件（.s3c）、层级目录结构等 管理海量的、分块多层级(LOD)存储的模型文件，确保数据能被正确加载和浏览。

常见gis数据及其格式 https://docs.fileformat.com/ 可以查看各种文件格式的基本信息
1. .ter
2. .tif geotiff ![alt text](tif文件结构.png)
   TIFF (Tagged Image File Format) is not just an image format, but a kind of universal "container". Imagine that this is not an ordinary photograph, but a digital folder capable of storing a lot of information. TIFF can contain an image of the highest quality, as well as all the accompanying information about it: where and when it was taken, what parameters it has, what colors were used, and so on. Thanks to its flexible structure, TIFF is widely used where the quality and integrity of data are more important than the file size.
   1. Header. A small "business card" at the very beginning of the file. It tells the program that this is a TIFF and where to find basic information about the image.
   2. Directory (IFD). This is the "index" or "contents" of the file. It contains a list of all the characteristics of the image, described as "tags".类似dcm的tag，可以保存宽 高 颜色空间 压缩格式 相机参数 拍摄位置时间等等信息
   3. Pixel data. The actual image itself.
3. DEM 可用于绘制等高线、坡度图、坡向图、立体透视图、立体景观图，并应用于制作正射影像（DOM）、立体地形模型与地图修测。所以，广义的DEM还包括等高线、三角网等所有表达地面高程的数字表示。
      ``` cpp 
      // DEM 数学表示就是一组离散的x y z，具体的
      struct DEMPoint {
         double x;        // 经度或东坐标
         double y;        // 纬度或北坐标  
         double z;        // 高程值
      };

      // 常见 DEM 格式
      enum DEMFormat {
         USGS_DEM,        // USGS DEM 格式
         SRTM,            // 航天飞机雷达地形任务SRTM（Shuttle Radar Topography Mission），由美国太空总署（NASA）和国防部国家测绘局（NIMA）联合测量。原始数据为geotif或ESRI GRID格式，每景数据覆盖经纬度各5°，水平和垂直精度分别为20和16m，水平分辨率约90m。
         ASTER_GDEM,      // ASTER 全球数字高程模型 从ASTER （advance spaceborne thermal emission and reflection radiometer）GDEM(global digital elevation model) 全球数据网站下载。原始数据为tif格式，每景数据覆盖经纬度各1°，数据的水平和垂直精度均为7~50m，水平分辨率约30m。参考大地水准面为WGS84/EGM96，特殊DN值：无效像素值为-9999，海平面数据为0
         TIN,             // 不规则三角网
         GRID             // 规则网格 高程矩阵
      };
      ```
     主要的表示模型有:规则栅格 等高线 TIN，还可以进行不同的渲染，如通过颜色等表达高低
      主要的文件格式有:
      GeoTIFF：一种常用的地理信息系统格式，支持地理参考的栅格图像。
      ASCII：一种文本格式，便于数据的读取和编辑。
      GRID：用于存储栅格数据的格式，适用于多种GIS软件。
      DTED（数字地形高程数据）：由美国国防部开发的标准格式，用于描述数字地形。 
      .ter：Terragen™ Terrain File

      . DEM Data : {"

         *.Flt : Floating Point Raster File,

         *.Ter : Terragen File,

         *.Tif (16-32bit) + Tilled Tiff : GeoTiff Files,

         *.Asc : Arc ASCII Grid format,

         *.Raw : Unity Heightmap data,

         *.Png Grayscale : Grayscale Pixel File ,

         *.Las : Lidar Point Cloud Format ,

         *.Hgt : Shuttle Radar Topography Mission (SRTM) Data,

         *.Bil : Band Interleaved by Line (BIL) Image File,

         *. Bin : Binary Float point "} .

         . Raster Data : { " *.jpg, *.Png " } .

         . Vector Data : { " *.Osm : OpenStreetMap Informations , *.Shp : ESRI Geometry data " } .

4. DTM 数字地面模型（Digital Terrain Model）x、y表示该点的平面坐标，z值可以表示高程、坡度、温度等信息，当z表示高程时，就是数字高程模型，即DEM。地形表面形态的属性信息一般包括高程、坡度、坡向等 ![alt text](温度图.png) ![alt text](日照图.png)
5. DSM DEM+地物 高程矩阵
   ```cpp
   std::vector<std::vector<double>> elevation_data;  // DSM 数据
   std::vector<std::vector<double>> dem_data;        // DEM 数据（如有）
   ```
6. DOM 卫片 tif png等带有地理信息的图像 是经过DEM高程模型几何校正、消除了地形误差的遥感影像地图，与人们感官的现实世界无异，我们现在看到的互联网卫星地图大多是正射影像产品 ![alt text](DOM.png)
7. TDOM ![alt text](真正正射图.png)
8. 地类图map2021_aster，泥土 草 树，是mask文件，png或者tif
9. shape .shp
10. .osm openstreetmap

[DEM-DTM-DSM-DOM解释及示例图](./DEM-DTM-DSM-DOM解释及示例图.pdf)


常用软件工具
​​自动化处理软件​​：
​​ContextCapture (Bentley)​​：行业标杆，生成的模型和点云质量极高。以前叫smart3d
​​Pix4D​​：非常流行，尤其在测绘和农业领域。
​​大疆智图 (DJI Terra)​​：对大疆无人机优化好，性价比高。
​​PhotoScan (现为Metashape, Agisoft)​​：功能强大，用户群体广。
​​点云分类与DEM编辑软件​​：
​​Global Mapper​​：功能全面，点云分类和DEM编辑功能非常强大且易用。
​​ArcGIS (3D Analyst模块)​​：GIS平台，适合后续的分析和展示。
​​CloudCompare​​：开源免费的强大点云处理软件，可以进行分类和导出，但自动化程度不如商业软件。

sketchup
cesium基于webgl 3dtiles(基于glTF)
osgEarth

earthmaker里面的文件格式 通用 专有

3S:GIS GPS RS


GIS中的距离和角度
geodisc测地距离

**gis数据中的几个概念**:
1. 水平vs垂直:水平是指地球表面的经纬度,垂直指高程或深度值
2. 分辨率(Resolution) 数据的详细程度
   1. 空间分辨率 每个像素代表的地面实际尺寸范围
        高分辨率：＜5米（如卫星影像）
        中分辨率：5-30米（如Landsat）
        低分辨率：＞30米（如气象数据）
   2. 光谱分辨率 
    传感器捕捉的光谱波段宽度和数量
    决定区分不同地物的能力
3. 精度(Accuracy) 数据的精确程度(误差值)
   1. 平面位置精度：
        像素水平位置与实际位置的偏差
        通常以米为单位（如±10米
   2. 高程精度：
        高程值与实际高度的偏差
        如数字高程模型（DEM）的高程误差
   3. 分类精度：
        对于分类数据，正确分类的比例

**数据分辨率大多数是90m 60m 30m 15m 5m 1m**

**二**、这些 DEM 分辨率是怎么来的？（核心：数据源 + 生产技术）
DEM 的分辨率本质是「高程数据的网格化采样间隔」，其数值直接由 *数据采集方式、传感器技术指标、后期处理算法* 决定，不同分辨率对应不同的生产技术路线：
1. 低分辨率（90m、60m）：卫星大范围遥感测绘
   核心数据源：卫星雷达（如 SRTM）、宽幅光学卫星（如早期 Landsat）
   生产流程：
   卫星搭载雷达 / 光学传感器，对全球 / 大范围区域进行扫描（如 SRTM 是航天飞机搭载雷达，2000 年对全球 60°N-56°S 区域进行全覆盖扫描）；
   通过「立体像对匹配」（光学卫星）或「雷达干涉测量（InSAR）」（雷达卫星），计算地面点高程；
   对原始高程点进行「网格化重采样」，按固定间隔生成规则格网 DEM。
   典型产品：
   90m：SRTM 3（SRTM 原始数据是 30m，为降低数据量、适配全球分发，重采样为 90m，又称 “SRTM 90m”）；
   60m：多为区域级 DEM（如部分国家将 1:25 万地形图数字化后，插值生成 60m 格网，适配宏观地形分析）。
2. 中分辨率（30m、12.5m）：中高分辨率卫星测绘
   核心数据源：中高分辨率光学卫星（如 ASTER、Landsat 8/9、ALOS）
   生产流程：
   卫星传感器的「瞬时视场（IFOV）」设计为对应分辨率（如 Landsat 8 的 OLI 传感器，地面采样距离（GSD）为 30m）；
   通过卫星立体影像（如 ASTER 卫星搭载前后视相机，获取立体像对）进行「数字摄影测量」，生成密集高程点；
   网格化后直接输出对应分辨率 DEM（无需大幅重采样，保留更多地形细节）。
   典型产品：
   30m：ASTER GDEM（全球 30m DEM，基于 ASTER 立体影像）、Landsat DEM（美国 USGS 发布，适配 Landsat 影像的像素大小）；
   12.5m：ALOS World 3D-30m（实际核心分辨率 12.5m，基于日本 ALOS 卫星的 PRISM 传感器，立体影像匹配精度更高）。
3. 高分辨率（5m、3m）：航空 / 无人机测绘 + LiDAR 点云
   核心数据源：航空摄影测量、无人机倾斜摄影、LiDAR（激光雷达）点云
   生产流程：
   近距离采集高密度高程数据（如 LiDAR 通过激光脉冲扫描地面，点云密度可达 1-10 点 / 平方米；无人机航拍获取厘米级立体影像）；
   对高密度点云 / 影像进行「插值处理」（如克里金插值、反距离加权），按 5m/3m 间隔生成格网 DEM（保证每个格网内有足够多原始点，确保高程准确性）；
   多用于小范围、高精度场景（如工程设计、矿山监测）。
   典型产品：
   5m：区域级航空摄影 DEM（如我国 1:1 万比例尺 DEM，常用 5m 分辨率）；
   3m：LiDAR DEM、无人机测绘 DEM（城市规划、道路设计常用）。
   补充：更高分辨率（1m 及以下）
   用户没提，但可辅助理解：1m、0.5m 分辨率多来自无人机 LiDAR、地面三维激光扫描，用于精细化场景（如建筑建模、边坡监测），本质是 “采集密度提升→分辨率提升” 的逻辑。

**三**、为啥是这些分辨率？（核心：技术 + 标准 + 需求）
这些数值不是随机设定的，而是「技术可行性、行业标准统一、应用需求适配」三者平衡的结果：
1. 技术限制：传感器设计的 “天然结果”
   卫星 / 传感器的硬件设计直接决定基础分辨率：
   卫星的「轨道高度」和「传感器焦距」固定时，地面采样距离（GSD）= 轨道高度 × 瞬时视场角（弧度）。例如：
   SRTM 航天飞机轨道高度约 233km，雷达传感器的扫描角设计导致原始 GSD 约 30m，重采样为 90m（3 倍放大）可平衡数据量和覆盖范围；
   Landsat 卫星轨道高度 705km，OLI 传感器焦距设计后，GSD 刚好为 30m（多光谱波段），成为中分辨率 DEM 的 “黄金标准”。
   LiDAR / 无人机：点云密度决定最小分辨率（如 1 点 / 平方米的 LiDAR 点云，最小可生成 3m 分辨率 DEM—— 若小于 3m，部分格网可能没有原始点，需过度插值导致误差增大）。
2. 行业标准：统一规格便于数据共享
   国际组织（如 USGS、NASA）和各国测绘部门（如我国自然资源部）会制定 DEM 标准，统一分辨率规格：
   避免 “碎片化”：若每个机构都用不同分辨率（如 27m、32m），数据无法直接叠加分析（如 DEM 与遥感影像配准）；
   兼容主流数据：30m 分辨率与 Landsat、Sentinel-2 等主流卫星影像的像素大小一致，方便 “地形 + 影像” 融合应用（如土地利用分类、植被覆盖分析）；
   历史传承：早期 DEM（如 USGS 的 1:24000 比例尺 DEM）分辨率约 30m，后续技术迭代中，30m、90m 等规格被保留并推广为全球通用标准。
3. 应用需求：梯度适配不同场景
   不同分辨率对应不同的使用场景，形成 “从宏观到微观” 的梯度：
   90m/60m：全球 / 大陆尺度分析（如气候模拟、流域划分、宏观地形格局研究）—— 无需细节，追求覆盖范围和计算效率；
   30m/12.5m：区域尺度分析（如省级生态保护、土壤侵蚀评估、城市扩张监测）—— 平衡细节和数据量；
   5m/3m：工程 / 小范围应用（如道路选线、水库设计、矿山开采监测）—— 需要高精度地形细节，容忍较小覆盖范围和较大数据量。
4. 数据效率：避免冗余与浪费
   分辨率越高，数据量呈平方级增长（如 30m DEM 的单个格网面积是 90m 的 1/9，相同区域数据量是 9 倍）：
   若用 3m 分辨率做全球 DEM，数据量会达到 PB 级，存储和计算都无法实现；
   若用 90m 分辨率做道路设计，无法识别小坡度、小沟壑等关键地形，导致工程风险。
   因此，选择这些分辨率是 “精度需求” 和 “数据效率” 的最优解。


## GDAL 核心类层次与协作关系
GDAL库支持的数据格式
光栅格式:https://gdal.org/en/stable/drivers/raster/
矢量格式:https://gdal.org/en/stable/drivers/vector/index.html

GDAL读取DEM数据与三维地形可视化实战 https://blog.csdn.net/weixin_34718952/article/details/151242951

arcgis列出的光栅数据格式
https://pro.arcgis.com/en/pro-app/latest/help/data/imagery/supported-raster-dataset-file-formats.htm

CPL:common portability library

GDAL（Geospatial Data Abstraction Library）的对象模型采用严格的继承层次，所有可见的"数据"和"驱动"都派生自 `GDALMajorObject` 这个根类。下图展示了核心类的继承关系：

```
                    ┌─────────────────────────┐
                    │   GDALMajorObject        │  ← 根类：元数据 + 错误处理
                    │   (基类)                 │
                    └──────────┬───────────────┘
                               │ 继承
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐    ┌────────▼────────┐    ┌────────▼─────────┐
│ GDALDriver      │    │  GDALDataset     │    │  GDALDriverMan-  │
│ (驱动/格式实现) │    │  (一个数据集)     │    │  ager (驱动管理) │
└────────────────┘    └────────┬────────┘    └──────────────────┘
                               │ 拥有
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐    ┌────────▼────────┐    ┌────────▼─────────┐
│ GDALRasterBand │    │  OGRLayer        │    │  GDALMulti-      │
│ (栅格波段)      │    │  (矢量图层)      │    │  Driver (多波段) │
└────────┬───────┘    └────────┬────────┘    └──────────────────┘
         │                     │
         ▼                     ▼
   GDALBlock              OGRFeature
   (数据块缓存)            (要素)
```

### 1. `GDALMajorObject` —— 所有 GDAL 对象的根基类

这是整个类层次的"祖宗"，负责所有派生类共有的两件事：

**职责**：
- **元数据管理**（Metadata）：以 `key=value` 字符串形式存储任意附加信息（如坐标系、创建时间、RPC 参数等）
- **错误状态管理**：维护 CPL 错误堆栈（`CPLError`、`CE_Fatal`、`CE_Failure` 等级别）

**关键方法**：

```cpp
// 元数据
void SetMetadata(const char *pszMetadata);             // 整体设置
const char *GetMetadataItem(const char *pszName);     // 查单个 key
char **GetMetadata(const char *pszDomain = "");       // 查整个域

// 描述
void SetDescription(const char *pszDescription);      // 名称/描述
const char *GetDescription();

// 错误处理（CPL 栈）
CPLErr GetLastErrorType();
const char *GetLastErrorMsg();
```

**为什么需要这个基类？** 因为 GDAL 设计目标之一是"用统一 API 操控 200+ 种格式"——`Dataset`、`Driver` 都要保存元数据、都要报告错误，所以抽出来作为根类。`GDALDataset` 和 `GDALDriver` 都通过多态获得 `GetMetadataItem()` 这样的统一接口。

### 2. `GDALDataset` —— 一个具体的数据集（一个文件/一个影像）

代表**一个打开的数据集**（一个 GeoTIFF 文件、一幅 Sentinel-2 影像、一张 shapefile 都对应一个 Dataset）。`GDALOpen()` 返回的就是它。

**类层次中的位置**：继承自 `GDALMajorObject`，是栅格 (`GDALDataset`) 和矢量 (`GDALDataset` 同一基类，OGR 通过 `OGRLayer` 扩展) 共同的容器。

**关键属性**：

| 属性 | 说明 |
|------|------|
| `nRasterXSize` / `nRasterYSize` | 影像宽高（像素） |
| `nBands` | 栅格波段数（矢量数据集为 0）|
| `GetProjectionRef()` | WKT 格式的坐标参考系 |
| `GetGeoTransform()` | 6 参数仿射变换（影像→地理坐标）|
| `GetDriver()` | 返回创建/打开该数据集的 `GDALDriver*` |
| `poDriver` | 同上，但内部成员 |

**关键方法**：

```cpp
// 打开（工厂方法）
GDALDatasetH GDALOpen(const char *pszFilename, GDALAccess eAccess);
GDALDatasetH GDALOpenEx(  // 新接口，支持更多选项
    const char *pszFilename,
    unsigned int nOpenFlags,
    char **papszAllowedDrivers,   // 限定驱动列表
    char **papszOpenOptions,
    char **papszSiblingFiles);

// 波段访问
int GetRasterCount();
GDALRasterBand* GetRasterBand(int nBand);   // 1-based

// 空间参考
OGRSpatialReference* GetSpatialRef();
CPLErr GetGeoTransform(double *padfTransform);  // 6 个 double

// 创建/写入新数据集（通过 Driver）
GDALDataset* GDALDriver::Create(
    const char *pszFilename,
    int nXSize, int nYSize, int nBands,
    GDALDataType eType,
    char **papszOptions);

// 关闭
CPLErr Close();  // 实际调用 GDALClose()
```

**两种数据集类型**：
- **栅格数据集**：有 `nRasterXSize/YSize`、`nBands`，通过 `GetRasterBand()` 取波段
- **矢量数据集**：实质是 `GDALDataset` 的子类 `OGRLayerContainer`，包含若干 `OGRLayer`（shapefile 会有 layer；GeoPackage 可能多个 layer）

两者通过同一 `GDALDataset` 基类表达，因此 `GDALOpen` 可以同时返回栅格或矢量。

### 3. `GDALDriver` —— 格式实现的封装

代表**一种数据格式的读写能力**。每个支持的格式（GeoTIFF、HDF5、PNG、Shapefile、GeoJSON、PostGIS...）都对应一个 `GDALDriver` 实例。

**类层次中的位置**：继承自 `GDALMajorObject`，与 `GDALDataset` 平级。

**关键属性**：

| 属性 | 说明 |
|------|------|
| `GetDescription()` | 短名（如 `"GTiff"`、`"PNG"`、`"MEM"`）|
| `GetMetadataItem(GDAL_DMD_LONGNAME)` | 长名（如 `"GeoTIFF"`）|
| `GetMetadataItem(GDAL_DMD_EXTENSIONS)` | 文件扩展名（如 `"tif tiff"`）|
| `GetMetadataItem(GDAL_DCAP_CREATE)` | `"YES"` 表示可创建 |
| `GetMetadataItem(GDAL_DCAP_RASTER)` / `GDAL_DCAP_VECTOR` | 是否支持栅格/矢量 |

**关键方法**：

```cpp
// 创建新数据集
GDALDataset* Create(const char *pszFilename,
                    int nXSize, int nYSize, int nBands,
                    GDALDataType eType,
                    char **papszOptions = nullptr);

// 创建副本（格式转换）
GDALDataset* CreateCopy(const char *pszFilename,
                        GDALDataset *poSrcDS,
                        int bStrict, char **papszOptions,
                        GDALProgressFunc pfnProgress,
                        void *pProgressData);

// 删除数据集
CPLErr Delete(const char *pszFilename);

// 复制文件
CPLErr CopyFiles(const char *pszNewName, const char *pszOldName);
```

**两种 Driver 形态**：
- **真实文件驱动**（GTiff、HDF5、PNG）：读写磁盘文件
- **内存驱动**（`MEM`）：在内存中构建数据集，不落盘，常用于算法中间结果

### 三者协作：一个完整的读图流程

以 `GDALOpen` 读取 GeoTIFF 为例，演示三者如何协作：

```
用户调用
    │
    ▼
GDALOpen("D:\\test.tif", GA_ReadOnly)
    │
    │ ① GDALDriverManager：浏览所有已注册 Driver
    ▼
GDALDriverManager::GetDriverByName("GTiff")
    │  ② 返回 GTiff Driver
    ▼
GTiff::Identify("D:\\test.tif")
    │  ③ 通过扩展名/魔数识别格式
    │  (返回 true)
    ▼
GTiff::Open("D:\\test.tif", GA_ReadOnly)
    │  ④ 读取 IFD、tile offset、压缩参数等
    │  ⑤ 构造 GDALDataset 子类 GTiffDataset
    │  ⑥ 在数据集内创建 n 个 GDALRasterBand
    ▼
返回 GDALDataset* 指针给用户
    │
    ▼
用户 ds->GetRasterBand(1)->RasterIO(...)
    │  ⑦ 通过 Dataset 拿到 Band
    │  ⑧ 通过 Band 读像素
```

**关键协作点**：

1. **DriverManager 是入口**：所有 Driver 在启动时通过 `GDALAllRegister()` 注册到全局单例 `GDALDriverManager`。
2. **Driver 是工厂**：`Open` / `Create` / `CreateCopy` 是 Driver 提供的工厂方法，返回 `GDALDataset*`。
3. **Dataset 是工厂的产品**：用 `GetDriver()` 反向拿回创建它的 Driver（用于格式转换、清理等）。
4. **MajorObject 提供共性**：Dataset 和 Driver 都能调用 `GetMetadataItem()` 查元数据、都能 `GetLastErrorMsg()` 查错误——这就是多态带来的统一 API。

### 实际代码示例：完整协作

```cpp
// 打开一张图
GDALDataset* ds = static_cast<GDALDataset*>(GDALOpen(imgFilename.c_str(), GA_ReadOnly));
if (!ds) {
    fprintf(stderr, "Open failed: %s\n", CPLGetLastErrorMsg());
    return;
}

// 通过 Dataset 拿到 Driver，反查格式信息
GDALDriver* drv = ds->GetDriver();
printf("Driver: %s / %s\n",
       drv->GetDescription(),
       drv->GetMetadataItem(GDAL_DMD_LONGNAME));

// 通过 Dataset 拿坐标
double gt[6];
if (ds->GetGeoTransform(gt) == CE_None) {
    printf("Origin: (%.2f, %.2f)\n", gt[0], gt[3]);
    printf("Pixel size: (%.6f, %.6f)\n", gt[1], gt[5]);
}

// 通过 Dataset 拿 Band，读像素
GDALRasterBand* band = ds->GetRasterBand(1);
int w = band->GetXSize(), h = band->GetYSize();
GByte* buf = (GByte*)CPLMalloc(w * h);
band->RasterIO(GF_Read, 0, 0, w, h, buf, w, h, GDT_Byte, 0, 0);

// 关闭（自动 delete）
GDALClose(ds);
```

### 总结对比表

| 类 | 角色 | 数量 | 关键方法 | 典型来源 |
|----|------|------|----------|----------|
| **GDALMajorObject** | 元数据 + 错误基类 | 1（基类）| `Set/GetMetadata`、`GetLastErrorMsg` | 不可直接实例化 |
| **GDALDataset** | 一个已打开的数据集 | 每文件/每数据集 1 个 | `GetRasterBand`、`GetDriver`、`GetGeoTransform` | `GDALOpen()` 返回 |
| **GDALDriver** | 一种格式的读写能力 | 每格式 1 个（全局共享）| `Open`、`Create`、`CreateCopy`、`Identify` | `GetDriverByName()` 取 |
| GDALDriverManager | 驱动注册表 | 1 个（单例）| `GetDriverByName`、`RegisterDriver` | `GDALGetDriverManager()` 取 |
| GDALRasterBand | 数据集内的一个波段 | 每数据集 N 个 | `RasterIO`、`ReadBlock`、`WriteBlock` | `ds->GetRasterBand(i)` 取 |
| OGRLayer | 矢量图层 | 每矢量数据集 N 个 | `GetNextFeature`、`CreateFeature` | `ds->GetLayer(i)` 取 |

**三者关系一句话**：`GDALMajorObject` 是根；`GDALDriver` 是"格式说明书 + 工厂"；`GDALDataset` 是"工厂生产出来的产品"；用户面向 `Dataset` 编程，`Driver` 在背后默默工作。

## GDALRasterBand —— 一个栅格波段（数据访问的真实入口）

`GDALRasterBand` 代表**一个波段**——也就是数据集中某一通道的二维像素矩阵（一张灰度图）。一张多光谱影像（如 8 波段 Sentinel-2）会有 8 个 Band 对象。

### 类层次

```
GDALMajorObject
   └── GDALDataset
         └── GDALRasterBand   ←  继承自 GDALMajorObject（不是直接继承 Dataset）
                                 实际关系：Dataset 拥有（owns）多个 Band
```

> 严格说 `GDALRasterBand` 也是 `GDALMajorObject` 的子类，与 `GDALDataset` 是兄弟关系；但生命周期上由 `GDALDataset` 拥有并销毁。

### 关键属性

| 属性 | 说明 |
|------|------|
| `nXSize` / `nYSize` | 波段宽高（像素）|
| `nBand` | 波段序号（1-based，与 GetRasterBand 参数一致）|
| `GetRasterDataType()` | 数据类型（`GDT_Byte`/`GDT_UInt16`/`GDT_Float32`/`GDT_Float64`...）|
| `GetBlockSize()` | 分块大小（GeoTIFF 通常 256×256 或 512×512）|
| `GetNoDataValue()` | NODATA 标记值 |
| `GetScale()` / `GetOffset()` | 物理值缩放/偏移（DN→反射率/辐亮度时用）|
| `GetUnitType()` | 单位字符串（如 `"meter"`、`"dB"`）|
| `GetColorInterpretation()` | 波段语义（`GCI_Red`/`GCI_Green`/`GCI_Blue`/`GCI_Alpha`/`GCI_PanSharp`...）|
| `GetOverviewCount()` / `GetOverview(i)` | 金字塔（金字塔图块）个数与第 i 个 |
| `GetMaskBand()` / `GetMaskFlags()` | 该波段的 NoData 掩码 |

### 关键方法：RasterIO（最常用）

RasterIO 是 Band 级别的"按需读写"，可读区域、重采样、改变数据类型：

```cpp
CPLErr RasterIO(
    GDALRWFlag eRWFlag,        // GF_Read 或 GF_Write
    int nXOff, int nYOff,      // 源窗口起点
    int nXSize, int nYSize,    // 源窗口大小
    void *pData,               // 目标缓冲
    int nBufXSize, int nBufYSize,  // 目标缓冲大小（!=源则重采样）
    GDALDataType eBufType,     // 目标数据类型
    int nPixelSpace,           // 同一行相邻像素的字节跨度
    int nLineSpace);           // 同一列相邻行的字节跨度
```

**应用示例**：

```cpp
GDALRasterBand* band = ds->GetRasterBand(1);
int w = band->GetXSize(), h = band->GetYSize();

// 读全图到缓冲（自动处理分块、重采样）
GByte* buf = (GByte*)CPLMalloc(w * h);
band->RasterIO(GF_Read, 0, 0, w, h, buf, w, h, GDT_Byte, 0, 0);

// 读区域 + 降采样到 1/2（自动重采样）
int dstW = w / 2, dstH = h / 2;
GByte* thumb = (GByte*)CPLMalloc(dstW * dstH);
band->RasterIO(GF_Read, 0, 0, w, h, thumb, dstW, dstH, GDT_Byte, 0, 0);
```

### 关键方法：块级 I/O（IReadBlock / ReadBlock）

按 `GetBlockSize()` 分块读写，是 RasterIO 的底层：

```cpp
int nXBlocks, nYBlocks;
band->GetActualBlockSize(&nXBlocks, &nYBlocks);  // 实际块大小

GByte* pBlock = (GByte*)CPLMalloc(nXBlocks * nYBlocks);
band->ReadBlock(0, 0, pBlock);  // 读 (0,0) 那个块
```

> 大多数场景用 RasterIO 即可；只有写自定义分块算法或金字塔时才需要直接 ReadBlock。

### 关键方法：统计与直方图

```cpp
double dfMin, dfMax, dfMean, dfStdDev;
band->GetStatistics(0, 1, &dfMin, &dfMax, &dfMean, &dfStdDev);
                                       // bApproxOK=0 精确 / bForce=1 强制重算

// 直方图（默认 256 bin）
GUIntBig* panHistogram = (GUIntBig*)CPLCalloc(256, sizeof(GUIntBig));
band->GetHistogram(panHistogram, 256, 0, 0, 0, 0, 0);  // 大多参数=0 走默认
```

### Band 在类图中的位置（修正版）

```
                    ┌──────────────────────┐
                    │   GDALMajorObject     │  ← 元数据 + 错误
                    └──────────┬───────────┘
                               │ 继承
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐    ┌────────▼────────┐    ┌────────▼─────────┐
│ GDALDriver      │    │  GDALDataset     │    │  GDALDriverMan-  │
│                 │    │  (1 数据集)       │    │  ager            │
└────────────────┘    └────────┬────────┘    └──────────────────┘
                               │ 拥有 1..N
                               ▼
                    ┌──────────────────────┐
                    │  GDALRasterBand       │  ← 1 波段（含分块/掩码/统计）
                    └──────────┬───────────┘
                               │ 拥有 0..N（每个波段可有多个）
                               ▼
                    ┌──────────────────────┐
                    │  GDALRasterBand       │  ← Overviews（金字塔）
                    │  (Overview)           │
                    └──────────────────────┘
```

**关键点**：
- `Dataset` 与 `Band` 是"容器—组件"关系（不是继承）
- `Band` 自己又可以包含若干 `Overview`（降采样图块，4×、16×、64×）
- `Band` 与 `Dataset` 都继承 `GDALMajorObject`，所以都可以查元数据、查错误
- 每个band的类型只能是GDALDataType，而这个是8 16 32 64位的整型 浮点 复数，所以每个band只能是一个数，而不能是多个数放进一个band(特殊编码可以实现但不是gdal原始语义)

### 实际用途

| 场景 | 关键方法 |
|------|----------|
| 读全图到内存 | `band->RasterIO(GF_Read, ...)` |
| 生成金字塔缩略图 | `band->RasterIO` + 重采样 + 写 JPEG/PNG |
| 直方图均衡化 | `GetHistogram` + 自定义 LUT + `RasterIO(GF_Write)` |
| 提取 NoData 掩码 | `GetMaskBand()->RasterIO` |
| 多波段合成真彩色 | 拿到 R/G/B 三个 band 分别读再合并 |
| 修改 NODATA | `SetNoDataValue` |
| 计算统计 | `ComputeBandStats` / `GetStatistics` |

### GDAL Band vs OpenCV Channel：同名不同义

**结论：不是同一个意思**，虽然在某些情况下巧合地一致。两者在数据模型、内存布局、用途上都有根本差异。

#### 核心差异

| 维度 | GDAL `GDALRasterBand` | OpenCV `cv::Mat` 通道 |
|------|----------------------|----------------------|
| **本质** | 一个**独立的二维矩阵对象**（独立元数据、可单独读写）| 一个 Mat 内部的**颜色通道槽位**（共享 header）|
| **内存布局** | 每个 Band 独立分配内存、独立访问 | 多通道 Mat 是**一块连续内存**，按 BGR/BGR2 顺序交错存储 |
| **独立性** | 每个 Band 是独立对象，可单独 open / close | 通道不能脱离 Mat 单独存在 |
| **元数据** | 每个 Band 有自己的 NoData、Scale、ColorInterp、Statistics | 通道几乎无元数据（除非显式存为单独 Mat）|
| **类型** | 数据类型**可以不同**（如 Band1=Byte, Band2=Float32）| 同一 Mat 内所有通道**类型必须相同** |
| **大小** | 理论上**可不同**（vrt 虚拟数据集允许异构）| 同一 Mat 所有通道**尺寸完全一致** |

#### 实际对比示例

##### OpenCV 视角（一个 PNG）

```cpp
cv::Mat img = cv::imread("D:\\test.png", cv::IMREAD_UNCHANGED);
// img.data 是一块连续内存，按 BGR(A) 顺序交错：
//   pixel0_B, pixel0_G, pixel0_R, pixel0_A,
//   pixel1_B, pixel1_G, pixel1_R, pixel1_A,
//   ...
// 访问第 i 个像素的 R：
img.at<cv::Vec4b>(row, col)[2];   // 0=B, 1=G, 2=R, 3=A
// 拆分通道 → 4 个独立 Mat（但每个只有 1 通道）
std::vector<cv::Mat> chans;
cv::split(img, chans);  // chans[0]=B, [1]=G, [2]=R, [3]=A
```

注意：**OpenCV 默认通道顺序是 BGR**（历史包袱），不是 RGB。

##### GDAL 视角（同一张 PNG）

```cpp
GDALDataset* ds = (GDALDataset*)GDALOpen("D:\\test.png", GA_ReadOnly);
// 4 个独立 Band 对象，各自是独立矩阵
GDALRasterBand* bR = ds->GetRasterBand(1);  // R
GDALRasterBand* bG = ds->GetRasterBand(2);  // G
GDALRasterBand* bB = ds->GetRasterBand(3);  // B
GDALRasterBand* bA = ds->GetRasterBand(4);  // A
// 读红色通道到内存（独立分配）
GByte* rData = (GByte*)CPLMalloc(W * H);
bR->RasterIO(GF_Read, 0, 0, W, H, rData, W, H, GDT_Byte, 0, 0);
```

#### 关键差异可视化

```
OpenCV cv::Mat（4 通道 PNG）：
┌────────────────────────────────────────────┐
│ data 缓冲区：连续的一块内存                 │
│ [B G R A B G R A B G R A ...]            │
│  ^^^^^^^^^^^  ^^^^^^^^^^^  ^^^^^^^^^^^     │
│  pixel 0      pixel 1      pixel 2         │
└────────────────────────────────────────────┘

GDAL 4 个 Band（4 通道 PNG）：
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Band 1:R │  │ Band 2:G │  │ Band 3:B │  │ Band 4:A │
│ [R R R R]│  │ [G G G G]│  │ [B B B B]│  │ [A A A A]│
│ R R R R  │  │ G G G G  │  │ B B B B  │  │ A A A A  │
│ R R R R  │  │ G G G G  │  │ B B B B  │  │ A A A A  │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
  4 块独立内存（实际 PNG 解码后也是分块存的）
```

#### 为什么 GDAL 要这样设计？

GDAL 的设计目标是**遥感 / 地理数据**，特点：

1. **波段数不固定**：Sentinel-2 有 13 个波段，Landsat-8 有 11 个波段，DEM 只有 1 个波段
2. **波段可能很大**：一幅 8 波段 Sentinel-2 影像是 ~1.6GB，不可能一次性装进一块连续内存
3. **波段可能异构**：波段 1（8-bit 反射率）+ 波段 2（16-bit 辐射亮度）+ 波段 3（32-bit 大气参数）
4. **需要分块读取**：常见 256×256 或 512×512 分块，支持分块解压 / 写入
5. **每个波段有独立语义**：NoData、Scale/Offset、ColorInterpretation、Statistics 都是按波段来的

OpenCV 的设计目标是**计算机视觉**，特点：

1. **通常 1/3/4 通道**（灰度 / BGR / BGRA）
2. **整张图一次性处理**（一般不大）
3. **同构数据**（所有通道类型相同）
4. **像素级操作密集**（滤波、卷积、几何变换）——需要连续内存

#### 但二者有重叠场景

| 场景 | GDAL 行为 | OpenCV 行为 |
|------|-----------|-------------|
| 读 PNG 显示 | 拿到 4 个 Band（RGBA 顺序）| 拿到 1 个 Mat（BGR 顺序，3 通道）|
| 读 GeoTIFF | 拿到 N 个 Band，**按波段存储**（planar）| 若 `cv::imread` 支持：拿到 1 个 Mat，**按像素交错**（pixel-interleaved，需手动 split）|
| 读 8 波段多光谱 | 8 个独立 Band（最自然）| 强行 split 成 8 个 Mat，或者用 `cv::MatND`，但很别扭 |
| 写 PNG | `Create("PNG", W, H, 4, GDT_Byte)` + 4 个 Band 分别写 | `cv::imwrite` 自动把 Mat 编码 |

> **OpenCV 不能直接读多波段遥感影像超过 4 通道的部分**，这就是为什么做遥感通常用 GDAL 或 rasterio（Python GDAL 绑定），而做视觉处理用 OpenCV。

#### 一张表看清区别

| 问题 | GDAL | OpenCV |
|------|------|--------|
| "一张 PNG 有几个 Band" | **4**（R/G/B/A）| 1 个 Mat，4 个通道 |
| 通道顺序 | 1=R, 2=G, 3=B, 4=A（**RGB**）| 0=B, 1=G, 2=R, 3=A（**BGR**）|
| 内存布局 | **Planar**（每波段独立）| **Pixel-interleaved**（BGR 顺序交错）|
| 各通道类型可不同？ | ✅ 可以 | ❌ 同一 Mat 必须相同 |
| 各通道大小可不同？ | ✅ VRT 允许 | ❌ 同一 Mat 必须相同 |
| 通道有独立元数据？ | ✅ Nodata/Scale/Stats/ColorInterp | ❌ 没有 |
| 能超过 4 通道？ | ✅ 任意 | ❌ 最多 4 通道（C 接口）/ 任意（C++ Mat 但 API 麻烦）|
| 适合场景 | 遥感、多光谱、地理数据 | 视觉、显示、滤波、几何 |

#### 互相转换

如果你既需要 GDAL 读多波段，又要用 OpenCV 做算法：

```cpp
// 1. GDAL 读全部波段到 planar 缓冲
std::vector<GByte*> bandData(nBands);
for (int i = 0; i < nBands; i++) {
    bandData[i] = (GByte*)CPLMalloc(W * H);
    ds->GetRasterBand(i + 1)->RasterIO(
        GF_Read, 0, 0, W, H, bandData[i], W, H, GDT_Byte, 0, 0);
}

// 2. 转为 OpenCV Mat（以 RGB 三通道为例）
cv::Mat bgr(W, H, CV_8UC3);
for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
        bgr.at<cv::Vec3b>(y, x)[0] = bandData[2][y * W + x];  // B
        bgr.at<cv::Vec3b>(y, x)[1] = bandData[1][y * W + x];  // G
        bgr.at<cv::Vec3b>(y, x)[2] = bandData[0][y * W + x];  // R
    }
}

// 3. 也可以用 cv::merge 把 planer 拼成交错
std::vector<cv::Mat> chans = {
    cv::Mat(H, W, CV_8UC1, bandData[0]),  // R
    cv::Mat(H, W, CV_8UC1, bandData[1]),  // G
    cv::Mat(H, W, CV_8UC1, bandData[2]),  // B
};
cv::Mat bgr;
cv::merge(chans, bgr);  // 自动按 RGB 顺序合成 BGR Mat（注意 OpenCV merge 顺序）
```

#### 一句话总结

> **GDAL Band ≈ 独立的多光谱波段对象**（planar，按波段存储，独立元数据，任意通道数），**OpenCV Channel ≈ Mat 内部的颜色通道槽位**（pixel-interleaved 交错存储，共享 Mat，1-4 通道）。名字一样，本质不同，适用场景也不同。

Sources:
- [GDALRasterBand vs OpenCV Mat 概念对比](https://gdal.org/en/stable/user/raster_data_model.html)
- [OpenCV Mat 多通道布局](https://docs.opencv.org/4.x/d3/d63/classcv_1_1Mat.html#a4b5e8538e1d0bd2cea5b5e21141a7c95)
- [GDAL 数据模型](https://gdal.org/en/stable/user/raster_data_model.html)

## GDALMultiDomainMetadata —— 多域元数据容器

GDAL 的元数据不是简单的"一个 map"，而是**多域（multi-domain）**的——同一个 `key` 在不同域下可以有不同的值。这是 `GDALMajorObject` 元数据系统的底层数据结构。

### 为什么需要多域？

不同应用/标准对同一对象的元数据有不同规范，GDAL 不希望混在一起：

| 域（Domain）| 用途 | 谁写 |
|-------------|------|------|
| `""`（默认域）| 通用描述、来源、创建时间 | 所有人 |
| `"RPC"` | 理性多项式系数（卫星几何校正）| 卫星数据驱动（GeoEye、Pleiades）|
| `"IMAGERY"` | 影像元数据（卫星、传感器）| GeoTIFF、IKONOS、WorldView |
| `"GEOLOCATION"` | 地理定位表 | GDAL Geolocation 驱动 |
| `"xml:XPATH"` | 用 XPath 访问嵌入 XML | 各种带元数据 XML 的格式 |
| `"json:"` | JSON 路径域 | 各种 JSON 元数据 |
| `"DERIVED_SUBDATASETS"` | 子数据集列表 | HDF5 / NetCDF 驱动 |
| `"SUBDATASETS"` | 子数据集信息 | HDF5 / NetCDF / GPKG |
| `"EXIF"` | EXIF 标签 | JPEG 驱动 |
| `"COLOR_PROCESSING"` | 颜色处理元数据 | 颜色相关驱动 |
| `"PhotometricInterpretation"` | 摄影测量解释 | GeoTIFF |

### 类层次

```
GDALMajorObject
   └── oMetadata  (GDALMultiDomainMetadata 成员)
                    │
                    ├── 域 "" (default)        → char** (key=value 列表)
                    ├── 域 "RPC"               → char**
                    ├── 域 "IMAGERY"           → char**
                    ├── 域 "xml:XPATH"         → char** 或嵌套 XML
                    └── ...
```

### 内部数据结构

`GDALMultiDomainMetadata` 内部是一个 `std::map<CPLString, std::vector<CPLString>>`（实际是 `CPLStringList`），键是域名字，值是该域下的 `key=value` 列表：

```cpp
// 简化版定义（gdal_priv.h 内部）
class CPL_DLL GDALMultiDomainMetadata {
    std::map<CPLString, CPLStringList> oMapMD{};   // 域 → (k=v 列表)
    std::map<CPLString, CPLStringList> oMapMetadata{};  // 旧式 RC 风格（兼容）
public:
    int GetKeys(const char *pszDomain, char ***papszValues);
    char **GetMetadata(const char *pszDomain = "");
    const char *GetMetadataItem(const char *pszName, const char *pszDomain = "");
    CPLErr SetMetadata(const char *pszMetadata, const char *pszDomain = "");
    CPLErr SetMetadataItem(const char *pszName, const char *pszValue, const char *pszDomain = "");
    CPLErr RemoveMetadata(const char *pszDomain);
    void Clear();
};
```

> 实际 GDAL 2.x 之后把这个类用 `std::map` 替代了老的 `CPLHashMap`，更现代、性能更好。

### 通过 `GDALMajorObject` 访问（公开 API）

用户**不直接持有** `GDALMultiDomainMetadata`（它是 `protected` 成员），但通过 `GDALMajorObject` 的公开方法间接操作：

```cpp
// 伪代码：内部就是转发到 oMetadata
const char* GDALMajorObject::GetMetadataItem(const char *pszName, const char *pszDomain) {
    return oMetadata.GetMetadataItem(pszName, pszDomain ? pszDomain : "");
}
```

### 实际使用示例

```cpp
// 1. 列出所有域
char** domains = ds->GetMetadataDomainList();
for (char** d = domains; d && *d; ++d) {
    printf("Domain: %s\n", *d);
}
CSLDestroy(domains);

// 2. 查默认域的某个 key
const char* src = ds->GetMetadataItem("SOURCE");
// 注意：默认域里通常没有标准 key，每个驱动自己定义

// 3. 查 RPC 域
char** papszRPC = ds->GetMetadata("RPC");
if (papszRPC) {
    for (char** kv = papszRPC; *kv; ++kv) {
        printf("  %s\n", *kv);  // LINE_OFF=..., SAMP_OFF=...
    }
}

// 4. 用 XPath 查 XML 域
const char* cloud = ds->GetMetadataItem(
    "Product/Footprint/CloudCover",  // XPath
    "xml:NSIDC_fffffff_gdaleres");    // xml: 前缀
```

### RPC 域的典型内容

```ini
LINE_OFF=2784.0
SAMP_OFF=2025.0
LAT_OFF=39.5
LONG_OFF=116.0
HEIGHT_OFF=50.0
LINE_SCALE=2784.0
SAMP_SCALE=2025.0
LAT_SCALE=0.2
LONG_SCALE=0.2
HEIGHT_SCALE=100.0
LINE_NUM_COEFF=...
LINE_DEN_COEFF=...
SAMP_NUM_COEFF=...
SAMP_DEN_COEFF=...
```

这些是高分卫星正射校正必需的 RPC 参数。

### IMAGERY 域的典型内容（GeoTIFF）

```ini
SatelliteId=GeoEye-1
CloudCover=10
SunAzimuth=178.5
SunElevation=54.2
AcquisitionDate=2018-08-15
```

### 核心要点

1. **`GDALMultiDomainMetadata` 是 `GDALMajorObject` 的 protected 成员 `oMetadata`**，用户通过 `GetMetadata`/`SetMetadata`/`GetMetadataDomainList` 间接访问。
2. **多域设计**让 GDAL 不用为每种元数据规范写新接口——直接换域名就行。
3. **最常用域**：`""`（默认）、`RPC`（卫星几何）、`IMAGERY`（影像属性）、`xml:XPATH`（嵌入 XML 查询）。
4. **内部结构**：`std::map<CPLString, CPLStringList>`，CPLStringList 内部是 `std::vector<std::string>`。

### 与其他类协作的时序（查 RPC）

```
ds->GetMetadata("RPC")
  │
  ▼
GDALMajorObject::GetMetadata("RPC")
  │
  ▼
oMetadata.GetMetadata("RPC")
  │
  ▼
return oMapMD["RPC"]  // 返回 char** 形式的 k=v 列表
```

调用链短而清晰：所有 MajorObject 子类都通过这个统一路径访问元数据，无论 Dataset、Band、Driver 还是 ColorTable 都能用 `GetMetadata("RPC")` 查 RPC（当然实际只有部分 Dataset 有 RPC）。


## GIS数据获取途径
搜 地理信息数据云
gisdata123 mlwzsy@126.com
https://passport.escience.cn/ mlwzsy@126.com 大写小写数字特殊字符
1. 地图服务
   1. google地图
   2. bing地图
   3. OpenStreetMap
   4. 高德地图
   5. 天地图
   6. 腾讯地图
2. 卫星影像
   1. 商业卫星影像
   2. 开源卫星影像
      1. Sentinel-2
      2. Landsat
      3. MODIS
      4. ASTER
      5. Planet
      6. DigitalGlobe
3. 国内
   1. 地理空间数据云http://www.gscloud.cn ![alt text](gscloud数据浏览.png) 
      - 数据命名规则:数据来源_行号_条带号, 行号按照纬度划分 条带号按照经度划分，如 ASTGTM_N09E001 表示北纬9度，东经1度的区域；srtm_25_02表示西经57.5 北纬52.5
   2. 天地图http://www.tianditu.gov.cn
   3. 国家卫星气象中心 http://www.nsmc.org.cn
   4. 中国科学院数据云 www.csdb.cn
   5. 国家地球系统科学数据共享平台 http://www.geodata.cn
   6. 国家基础地理信息中心 http://www.ngcc.cn
   7. 资源环境数据云平台 http://www.resdc.cn
   8. 水经注地图 http://www.rivermap.cn
4. 国外
   1. NASA Earthdata https://earthdata.nasa.gov
   2. Natural Earth http://www.naturalearthdata.com
   3. OpenStreetMap https://www.openstreetmap.org
   4. USGS Earth Explorer https://earthexplorer.usgs.gov
   5. FAO GeoNetwork https://foo.org
5. 常见dem数据 常用的数字高程模型（DEM）数据：​
    1. ETOPO（1.8千米）
       ETOPO是一种地形高程数据，由NGDC美国地球物理中心发布，与大多数高程数据不同的是，它还包含海底地形数据。
    2. SRTM15（450米）
       SRTM15的空间分辨率为 15 弧秒，精度相当于 0.5km左右，包含了陆地高程和海洋深度数据。
    3. GMTED（250米）
       来自美国地质勘探局USGS和美国国家地理空间情报局NGA，它是对USGS的GTOPO30的进一步优化和发展，对应的最高精度在250米左右。
    4. SRTM3（90米）
       SRTM，全称为Shuttle Radar Topography Mission，该项目获取了北纬60度至南纬60度之间的雷达影像数据，SRTM3，即精度为3弧秒，即90m一个点，包括非洲、北美、南美、欧亚、澳大利亚以及部分岛屿。
    5. ASTER GDEM（30米）
       全称Advanced Spaceborne Thermal Emission and Reflection Radiometer Global Digital Elevation Model ，即先进星载热发射和反射辐射仪全球数字高程模型，其数据覆盖范围为北纬83°到南纬83°之间的所有陆地区域，达到了地球陆地表面的99%，所以应用十分的广泛。目前比较常用的是 ASTER GDEM V2，另外ASTER GDEM V3也比较常见，质量比V2版本要好的多。
    6. ALOS（12.5米）
       ALOS DEM是ALOS（Advanced Land Observing Satellite卫星相控阵型L波段合成孔径雷达（PALSAR）采集，该数据水平及垂直精度可达12.5米。
    7. 5米分辨率DEM&DSM(无控)
       5米分辨率DEM/DSM(无控)，以多颗高分辨率卫星数据为原始数据，基于智能立体模型构建与点云密集匹配，利用网络分布式与多核并行计算技术，三维点云融合与地形提取技术，辅以智能化的人机交互编辑等手段，处理和制作5m×5m空间分辨率的数字地表模型（DSM）和数字高程模型（DEM）。


## 坐标系

一般东经 北纬作为正数

极半径 6356752 米  
平均半径 6371008 米  
赤道半径6378137 米  
纬度每差一度，距离大概是111km, 每隔一分是1.85km 每隔一秒是30.8m 
经度每差一度，距离会随着纬度的变化而变化，纬度越高，经度每差一度，距离越小，纬度越低，经度每差一度，距离越大，经度每差一度的距离=111km*cos(纬度)

```c++
dvec3 world_ori_in_wgs =	e->toWGS(dvec3(0,0,0));//世界坐标系原点(地心)的经纬高(0,90,-6356752)应该等价于(0,0.-6378137)
dvec3 wgsv_xaxis_in_world =	e->toWorld(dvec3(0,0,0));//东经0°北纬0°的地球表面点(wgs坐标系的x轴,赤道平面上一点)的世界坐标系(6378137.0000000000,0,0)
dvec3 wgsv_yaxis_in_world =	e->toWorld(dvec3(90,0,0));//东经90°北纬0°的地球表面点(wgs坐标系的y轴,赤道平面上一点)的世界坐标系(0,6378137,0)
dvec3 wgsv_zaxis_in_world =	e->toWorld(dvec3(0,90,0));//东经0°北纬90°的地球北极点(wgs坐标系的z轴,北极点)的世界坐标系(0,0,6356752.3142451795)
dvec3 wgsv_south_pole_in_world = e->toWorld(dvec3(0,-90,0));//东经0°南纬90°的南极点(wgs坐标系的-z轴,南极点)的世界坐标系(0,0,-6356752.3142451795)
```

![alt text](真实世界的一点到屏幕上像素的坐标变换.png)

![alt text](北极圈穿过的国家.png)
![alt text](本初子午线穿过的国家.png)
![alt text](经纬线穿过的地区.png)
![alt text](经纬线穿过的国家地图.png)

东西经0°:英国格林尼治天文台 非洲
东经90°:俄罗斯 中国新疆青海西藏 印度 印度洋
东经180°:太平洋 白令海峡 阿拉斯加 俄罗斯
南北纬0°:赤道 非洲 亚洲 南美洲 

东经90°、100°、110°、120°在我国分别穿过的省份和地形如下：

东经90°： 穿过的省份：新疆、青海、西藏。 穿过的地形：主要包括塔里木盆地、青藏高原。

东经100°： 穿过的省份：内蒙古、甘肃、青海、四川、云南。 穿过的地形：从北到南依次有内蒙古高原、河西走廊、青藏高原东部、横断山脉、云贵高原。

东经110°： 穿过的省份：内蒙古、陕西、湖北、重庆、湖南、广西、广东、海南。 穿过的地形：从北到南依次有内蒙古高原、黄土高原、秦巴山地、四川盆地东部、长江中下游平原、云贵高原东南部、两广丘陵、海南岛。

东经120°： 穿过的省份：内蒙古、辽宁、山东、江苏、浙江、福建、台湾。 穿过的地形：从北到南依次有大兴安岭、东北平原、华北平原东部、长江三角洲、杭嘉湖平原、东南丘陵、台湾岛。

北京:东经115° 北纬40°

1. 常见坐标系
   1. 大地坐标系:定位地球上的点 用经度 纬度 高程表示 lambda phi h
   A geodetic system uses the coordinates (lat,lon,h) to represent position relative to a reference ellipsoid.大地坐标系使用经纬高来表示相对于参考椭球面的位置  
	是最基础、最常用的坐标系 大地测量坐标系用来测量测绘的  
    由于地球不是完美的椭球体 需要定义一个基准椭球体来表示地球  
    根据参考椭球的不同，有很多种坐标系，比如 CGCS2000、Beijing 1954 等
	事实上的标准是WGS84 World Geodetic System 1984:  
    - 本初子午线(英国格林尼治天文台)以东或以西
    - 赤道(非洲 亚洲 南美洲)以北或以南
    - 高程相对于 ​​WGS 84 椭球面​​的高度（单位：米）。请注意，这不同于我们常说的“海拔高”（相对于大地水准面）
    
   2. 地心地固直角坐标系:计算机内部计算使用 ECEF
        原点在地球质心
        z轴指向北极点
        x轴指向本初子午线与赤道的交点,即经度0 纬度0的点
        y轴指向东经90度 北纬0° 大概是印度洋 新疆西藏云南南部位置
        xyz轴构成右手系
        xyz轴的单位是米  
        ![alt text](ECEF.png)
        又叫geocentric corrdinate system 地心直角坐标系，地球坐标系
        术语 geocentric​ 更侧重于描述坐标系的几何属性，即原点位于地心。而 ECEF​ 这个名称则进一步强调了该坐标系的物理特性——它不仅原点在地心，而且还与地球固联，并随着地球一起旋转。正因为地球的自转，ECEF 是一个非惯性参考系
        通过cartesian坐标(x,y,z)表示相对于地心的位置，而地心与参考椭球球心的距离取决于采用的reference ellipsoid.  
        An Earth-centered Earth-fixed (ECEF) system uses the Cartesian coordinates (X,Y,Z) to represent position relative to the center of the reference ellipsoid. The distance between the center of the ellipsoid and the center of the Earth depends on the reference ellipsoid. 因此可以转换到大地坐标系
   3. 投影坐标系:在平面上展开地球
      1. Mercator投影:google地图 bing地图 OpenStreetMap等web地图服务底层都是墨卡托投影 保持形状不变，等角投影, 但面积变形严重
      2. UTM投影:美国通用，将地球划分为60个区域，每个区域投影到平面，区域内的坐标是UTM坐标，区域外的坐标是经纬度坐标
      3. 信息
   4. 站心坐标系/局部坐标系  基于大地坐标系下某一点的坐标系
      1. East-North-Up Coordinates enu ![alt text](enu坐标系.png)
      2. North-East-Down Coordinates ned ![alt text](ned坐标系.png)
      3. Azimuth-Elevation-Range Coordinates aer ![alt text](aer坐标系.png)

### 第一部分：GIS中常见的坐标系

GIS坐标系主要分为两大类型：**地理坐标系** 和 **投影坐标系**。

#### 1. 地理坐标系

*   **核心思想**：用经纬度来描述地球上任意一个点的位置。它是一个**三维球面**模型。
*   **基准面**：由于地球不是一个完美的球体，而是一个近似椭球体（梨形），为了精确测量，我们需要一个参考椭球体来拟合地球。**基准面就是定义了特定参考椭球体及其与地球相对位置的数学模型**。
    *   **地心基准面**：以地球质心为原点，最适合全球测量（如GPS）。
    *   **区域基准面**：最优化拟合某个特定区域（如北美），该区域测量更准，但其他区域偏差可能较大。
*   **单位**：十进制度度（Decimal Degrees, DD）。
*   **特点**：
    *   是**未投影**的坐标系。
    *   直接基于椭球体表面测量。
    *   在不同地区，**一度经纬度所代表的实际距离是不同的**（越靠近两极，经线越密集）。

**常见的地理坐标系：**

1.  **WGS84**
    *   **全称**：World Geodetic System 1984
    *   **基准面**：地心基准面。
    *   **应用**：**GPS全球卫星定位系统**的统一标准，也是目前网络地图（如Google Earth）的默认坐标系。是全球应用最广泛的坐标系。

2.  **CGCS2000**
    *   **全称**：中国国家大地坐标系 2000
    *   **基准面**：地心基准面。
    *   **应用**：**中国法定的国家坐标系**，用于一切测绘活动。它与WGS84在厘米级精度上非常接近，通常可以视为等同。

3.  **Beijing 1954 / Beijing 54**
    *   **基准面**：区域基准面（参考苏联的克拉索夫斯基椭球体）。
    *   **应用**：中国在2008年前广泛使用的地形图坐标系。现在正逐步被CGCS2000取代。与WGS84/CGCS2000之间存在较大偏差（可达100-200米）。

4.  **Xian 1980 / Xian 80**
    *   **基准面**：区域基准面（参考IAG 1975椭球体）。
    *   **应用**：在Beijing 54之后，CGCS2000之前使用，主要用于中国 mainland 的测绘。

---

#### 2. 投影坐标系

*   **核心思想**：将不可展平的**地球椭球面**通过某种数学法则**展开**到**二维平面**上。这个过程必然会产生**变形**（形状、面积、距离或方向的变形）。
*   **构成**：投影坐标系 = 地理坐标系 + 投影方法。
*   **单位**：米、英尺等长度单位。
*   **特点**：
    *   是**投影后**的坐标系。
    *   在二维平面上，坐标是 Cartesian 的（X, Y）。
    *   适用于面积量算、距离测量、规划绘图等。

**常见的投影方法与坐标系：**

1.  **Web Mercator (EPSG:3857)**
    *   **投影类型**：墨卡托投影的变种。
    *   **特点**：**等角**投影，保持方向不变形，但**面积变形严重**（高纬度地区被极度放大）。
    *   **应用**：**几乎所有在线地图服务的标准**，如Google Maps, Bing Maps, OpenStreetMap, 百度地图，高德地图。

2.  **UTM (Universal Transverse Mercator)**
    *   **投影类型**：横轴墨卡托投影。
    *   **特点**：将全球分为60个经度带（每个带6度经度），每个带单独投影，变形较小。是**等角**投影。
    *   **应用**：全球范围的大中比例尺地图（如1:100万至1:1万），军事、工程、科研领域广泛应用。中国范围内的带号一般为43-53。

3.  **Gauss-Krüger / 高斯-克吕格投影**
    *   **投影类型**：横轴墨卡托投影的一种。
    *   **特点**：与UTM类似，但采用3度分带或6度分带，中央经线比例系数为1（UTM为0.9996）。
    *   **应用**：**中国基本比例尺地形图（1:50万及更大比例尺）** 的官方投影。常与Beijing 54或CGCS2000基准面结合使用，形成如 `CGCS2000_3_Degree_GK_Zone_39` 这样的投影坐标系。

4.  **Albers Equal Area Conic (阿尔伯斯等积圆锥投影)**
    *   **投影类型**：圆锥投影。
    *   **特点**：**保持面积相等**，适合进行国家或大洲级别的面积统计分析。
    *   **应用**：中国全国范围的专题地图，特别是需要精确比较面积的场景（如人口密度、农作物分布）。

---

### 第二部分：坐标变换

坐标变换是将空间数据从一种坐标系转换到另一种坐标系的过程。根据情况不同，它可能包含以下一个或多个步骤。

#### 1. 坐标转换的主要类型

1.  **地理变换**
    *   **定义**：在不同**基准面**（即不同地理坐标系）之间进行转换。这是最复杂的一步，因为涉及到椭球体的改变。
    *   **方法**：
        *   **三参数/七参数法**：通过平移、旋转、缩放来建立两个椭球体之间的关系。七参数法精度更高。需要已知至少3个公共控制点来求解参数。
        *   **格网变换法**：使用一个偏移量查询表（如NADCON、NTv2）来修正不同基准面之间的差异，精度非常高。

2.  **投影变换**
    *   **定义**：在同一基准面下，将数据从**一种投影方法**转换为**另一种投影方法**。
    *   **例子**：将UTM投影的数据转换为阿尔伯斯等积投影。这个过程是纯数学的，不改变基准面。

3.  **基准面+投影变换**
    *   **定义**：最常见的完整坐标变换过程。既改变了基准面，也改变了投影方法。
    *   **例子**：将 `Beijing 1954 GK Zone 20` 的数据转换为 `WGS84 UTM Zone 50N`。

#### 2. 坐标变换的实践流程

在GIS软件（如ArcGIS, QGIS）中进行坐标变换时，通常遵循以下原则和步骤：

1.  **定义投影**：
    *   如果数据没有坐标系信息（即“未知坐标系”），你需要**告诉软件它当前是什么坐标系**。这一步只是添加元数据，并不改变数据本身的坐标值。

2.  **投影/变换**：
    *   将数据从当前的坐标系**转换**到你需要的目标坐标系。这一步会**重新计算并改变数据的坐标值**。

**黄金法则**：
*   **当两个坐标系的基准面不同时，必须使用地理变换（即需要指定转换参数）。**
*   如果只进行投影变换（基准面相同），则不需要地理变换参数。

#### 3. 常见问题与注意事项

*   **“火星坐标”问题**：在中国，从GPS设备（WGS84）获取的坐标，在用于百度地图或高德地图前，需要经过一个特殊的加密算法（GCJ-02）进行偏移。这是一个非标准的坐标变换，需要专门的库来处理。
*   **参数选择**：从Beijing 54或Xian 80转换到WGS84/CGCS2000时，务必选择正确的转换参数。使用错误的参数会导致几十到上百米的误差。
*   **动态地心基准**：像WGS84和CGCS2000这样的地心基准面本身也会随着测量技术的进步而微调（通过参考框架实现，如ITRF），在处理高精度应用时需要注意版本。

### 总结

| 操作 | 输入 | 输出 | 是否改变坐标值 |
| :--- | :--- | :--- | :--- |
| **定义投影** | 无坐标系信息的数据 + 正确的坐标系定义 | 具有正确坐标系信息的数据 | **否** |
| **投影** | A投影坐标系的数据 | B投影坐标系的数据（**基准面相同**） | **是** |
| **变换** | A地理坐标系的数据 | B地理坐标系的数据（**基准面不同**） | **是** |
| **投影与变换** | A投影坐标系的数据 | B投影坐标系的数据（**基准面不同**） | **是** |

理解坐标系和坐标变换是确保GIS数据空间位置准确性的关键。在处理任何空间数据时，第一步永远是**确认其当前的坐标系定义**。

## ECEF跟wgs84理解
这些问题问到根上了，我直接给你拆清楚。

---


### 一、ECEF 坐标系有标准吗？不同软件里一样吗？

**有标准，而且全球统一，不同 GIS 软件里完全一样。**

ECEF 的定义由 **IERS（国际地球自转服务）** 维护，具体标准是 **ITRS（国际地球参考系）**。WGS84 是 ITRS 的一个具体实现，两者差异极小（厘米级），日常使用视为等同。

ECEF 的三轴定义：
- **原点**：地球质心（含海洋和大气）
- **Z 轴**：指向 IERS 定义的参考极（CTP，约等于北极）
- **X 轴**：指向本初子午线与赤道交点（格林尼治）
- **Y 轴**：构成右手系（东经 90° 方向）

**无论你用 ArcGIS、QGIS、Proj、GDAL、Cesium、Google Earth，对同一个 WGS84 坐标 (φ, λ, h)，算出来的 ECEF (X, Y, Z) 完全一致**，因为都遵循同一套椭球参数和公式。

唯一的微小差异来自不同版本的 WGS84 实现（G730、G1150 等），但这些差异在分米级以下，对天空盒、渲染、导航来说完全可以忽略。

---

### 二、WGS84 → ECEF 的变换是固定的矩阵吗？

**不是矩阵，是一组非线性公式，但它是固定的、确定性的。**

WGS84 到 ECEF 的转换是**大地坐标到笛卡尔坐标**的转换，不是线性变换，不能用单个矩阵表示：

```
N = a / sqrt(1 - e² sin²φ)          // 卯酉圈曲率半径，随纬度变化
X = (N + h) cosφ cosλ
Y = (N + h) cosφ sinλ
Z = (N(1 - e²) + h) sinφ
```

其中 a = 6378137m（长半轴），e² = 0.00669437999014（第一偏心率平方），都是**固定常数**。

所以：
- **不是矩阵**：因为 N 随 φ 变化，是非线性关系
- **但是固定的**：给定相同的 φ, λ, h，任何人用这套公式都能算出相同的 X, Y, Z

反变换（ECEF → WGS84）需要迭代求解，也不是矩阵。

---

### 三、和 ENU 坐标的关系

**ENU 是 ECEF 经过旋转和平移得到的局部坐标系。**

#### 数学关系

给定站心点 P₀ 的 WGS84 坐标 (φ₀, λ₀, h₀)，先转成 ECEF 得到 (X₀, Y₀, Z₀)。

对于任意点 P 的 ECEF 坐标 (X, Y, Z)，它在 P₀ 处的 ENU 坐标为：

```
ΔX = X - X₀
ΔY = Y - Y₀
ΔZ = Z - Z₀

[e]   [ -sinλ₀       cosλ₀       0    ] [ΔX]
[n] = [ -sinφ₀cosλ₀  -sinφ₀sinλ₀  cosφ₀] [ΔY]
[u]   [  cosφ₀cosλ₀   cosφ₀sinλ₀  sinφ₀] [ΔZ]
```

这个旋转矩阵 **R** 是**正交矩阵**（R⁻¹ = Rᵀ），它将 ECEF 的全局坐标旋转到当地的东-北-天方向。

#### 关键区别

| 特性 | ECEF | ENU |
|---|---|---|
| 范围 | 全球 | 局部（站心附近几十公里） |
| 原点 | 地心 | 地表某点 |
| 轴方向 | 固定（指向北极/本初子午线） | 随站心位置变化 |
| 线性 | 非线性（WGS84↔ECEF） | 线性（ECEF↔ENU 是旋转+平移） |
| 适用 | 全球轨道、卫星导航 | 无人机、自动驾驶、局部渲染 |

#### 直观理解

- **ECEF**：地球绑定的全局笛卡尔坐标，像个巨大的三维网格钉在地球上
- **ENU**：你在某地站着，脚下是原点，东是 x，北是 y，天是 z

**ECEF → ENU 的过程**：先把 ECEF 原点移到站心（平移），再把坐标轴旋转到当地东-北-天方向（旋转）。这个旋转矩阵就是由站心的 φ₀, λ₀ 决定的。

---

### 四、回到你的天空盒问题

现在你应该清楚了：

1. **你的 ENU 天空纹理**：是在站心 (φ₀, λ₀) 处，以当地东-北-天为轴拍摄的天空
2. **要转成 ECEF 天空盒**：就是把每个像素的视线方向从 ENU 坐标系旋转到 ECEF 坐标系
3. **这个旋转是线性的**：用一个 3×3 正交矩阵就能完成（就是我给你的代码里那个 Rᵀ）

**所以之前给你的代码是正确的核心逻辑**：对输出天空盒的每个方向，先算出它在 ECEF 下的坐标，然后用 Rᵀ 转回 ENU，再去采样原纹理。

---

### 五、一句话总结

- **ECEF 有全球统一标准**，所有 GIS 软件算出来都一样
- **WGS84 → ECEF 是固定公式，不是矩阵**，但结果是确定性的
- **ENU 是 ECEF 的局部版本**，通过旋转+平移得到，旋转矩阵由站心经纬度唯一确定

如果你还想知道 WGS84 不同版本（WGS84(G1150) vs ITRF2014）之间的差异对天空盒是否有影响——答案是**完全没有**，差异在厘米级，对天空这种无限远的物体来说完全可以忽略。


## 升角 仰角 高度角 方位角 天顶角
elevation、azimuth 和 zenith 是天文学、地理学和相关工程领域（如卫星通信、导航）中描述目标在天空中位置的常用术语。

1.  **Elevation (仰角 / 高度角)**
    *   **含义**：目标相对于当地地平线的角度。地平线为 0°，头顶正上方（天顶）为 90°。
    *   **名称**：仰角、高度角。

2.  **Azimuth (方位角)**
    *   **含义**：目标在水平方向上的角度，通常从正北方向开始，沿顺时针方向测量。正北为 0°，正东为 90°，正南为 180°，正西为 270°。
    *   **名称**：方位角。

3.  **Zenith (天顶)**
    *   **含义**：观测者头顶正上方的点，是天空中的最高点。其**仰角固定为 90°**。
    *   **名称**：天顶。与它相对的点（脚底正下方）称为“天底”。

**简单来说**：要确定一个天体或卫星的位置，你需要两个角度：
*   **方位角 (Azimuth)**：告诉你在水平方向上朝哪个方向看（像指南针）。
*   **仰角 (Elevation)**：告诉你朝那个方向看时，视线需要抬高多少度。
*   **天顶 (Zenith)** 是一个特殊的参考点，即仰角为90°的位置。

这三个参数共同构成了“地平坐标系”，是定位空中目标的基础。


## gis 引擎
高德地图是一个基于GIS和瓦片图技术的在线地图服务提供商，提供地图显示、导航、地理编码、路径规划等服务。

Leaflet和Mapbox是两个常用的开源JavaScript库，用于创建交互式地图应用程序。它们可以与不同的地图提供商和数据源集成，包括高德地图和Mapbox本身。

Cesium是一个基于WebGL的虚拟地球和地图开发平台，可以用于创建高度可视化的三维地图应用程序。与其他工具不同，Cesium的重点是3D地图可视化，因此它可以用于创建高度交互式的虚拟地球、卫星图像、城市和地形等应用程序。

osgearth

OpenLayer,LeafLet,arcgis api等都属于企业级地图应用开发库

arcgis qgis

unigine 太像了...


## 数据切片
切片是指将​​原始DEM数据​​（如整块GeoTIFF或HGT文件）切割成​​多层级瓦片金字塔​​（Tile Pyramid），每个瓦片（Tile）覆盖特定地理范围和分辨率，按需动态加载，提升性能  
原始的dem及影像数据就是最高的空间分辨率，不断下采样得到各层级的瓦片数据，最低分辨率的瓦片数据对应金字塔的最底部分，是0级瓦片

金字塔层级 0 2 4 6 8 14  
金字塔最底层是0级 层级对应的数值越大 精度越高 所以原始dem的精度就决定了金字塔的层数
LOD层级  
瓦片大小 图像分辨率 图像尺寸 瓦片尺寸 瓦片数量

理解DEM数据切片中的这些概念对构建高效的三维地形服务至关重要。下面这个表格汇总了它们的核心定义与区别，方便你快速把握要点。

| 概念 | 核心定义 | 关注点与说明 |
| :--- | :--- | :--- |
| **金字塔层级 (Pyramid Level)** | 瓦片金字塔的级别编号，通常从**0**开始。层级越高（数字越大），分辨率越高，展示细节越丰富。 | 定义了瓦片的**全局索引级别**，是瓦片坐标（Z、X、Y）中的Z值。 |
| **LOD层级 (Level of Detail)** | 根据观察点距离，动态切换不同金字塔层级的瓦片，以平衡渲染效果和性能。 | 一种**动态调度策略**，其基础是预先切好的金字塔层级。 |
| **瓦片数量 (Number of Tiles)** | 在特定金字塔层级下，覆盖整个DEM数据区域所需的瓦片总个数。 | 由数据地理范围、金字塔层级和瓦片**地理大小**共同决定。 |
| **瓦片大小 (Tile Size)** | 单个瓦片所代表的**实际地理范围**（如经度0.01度 × 纬度0.01度）。 | 一个**地理空间**概念，表示瓦片覆盖的实际地面面积。 |
| **瓦片图像尺寸 (Tile Image Dimensions)** | 瓦片作为图片文件时的**像素分辨率**，如经典的256×256或512×512。 | 一个**图像渲染**概念，尺寸越大，能描绘的地形细节越精细。 |
| **瓦片图像分辨率** | 每个像素所代表的地面实际大小（米/像素），由**瓦片大小**除以**瓦片图像尺寸**得出。 | 衡量地形模型精度的关键指标，值越小，精度越高。 |

### 💡 概念详解与关联

#### 1. 层级管理：金字塔层级 vs LOD层级

-   **金字塔层级 (Pyramid Level)**：这是数据的**静态组织结构**。就像真实的金字塔一样，第0层是覆盖全球但最粗糙的一张（或几张）瓦片；随着层级提高，每张瓦片覆盖的地理范围变小，但表示该区域的原始数据精度得以保留，从而展示更多细节。例如，第14级瓦片可能只覆盖一个城市街区。
-   **LOD层级 (Level of Detail)**：这是一种**动态渲染优化技术**。在实时渲染时，计算观察点（相机）到每个瓦片的距离。距离远的瓦片，即使存在更高金字塔层级的数据，也使用较低层级的瓦片来渲染，因为细节难以察觉。这能显著降低GPU负载，避免不必要的细节渲染。

**核心关系**：LOD机制依赖于已经构建好的金字塔层级。可以理解为，金字塔层级是“原材料”，而LOD是决定“在什么距离上使用哪种原材料”的智能调度策略。

#### 2. 瓦片度量：数量、大小与分辨率

-   **瓦片数量**：这个数量直接取决于你的数据面积和金字塔层级。有一个近似关系：在第 `Z` 级，全球范围大约会被划分为 `2^Z × 2^Z` 个瓦片。你的DEM数据覆盖其中多少，就决定了该层的瓦片数量。
-   **瓦片大小 vs 瓦片图像尺寸**：这是最容易混淆的一对概念。关键在于区分**地理空间**和**图像像素**。
    -   **瓦片大小**是地理概念，比如一个瓦片固定代表1平方公里。
    -   **瓦片图像尺寸**是像素概念，比如用256×256个像素点来描绘这1平方公里。
    -   两者共同决定了**分辨率**：如果1平方公里的地形用256像素宽的图片表示，那么分辨率大约是 `1000米 / 256像素 ≈ 3.9米/像素`。图像尺寸越大，每个像素代表的地面尺寸就越小，分辨率就越高。

### 🛠️ 实践中的选择与平衡

在实际项目中，这些概念转化为一系列需要权衡的决策：

-   **如何设定最大金字塔层级？** 这取决于你的**原始DEM数据精度**。例如，1米分辨率的DEM数据可以切到比30米分辨率SRTM数据高得多的层级，因为后者在高层级下并无可供显示的更多真实细节。
-   **如何选择瓦片图像尺寸？** 主流选择是256x256或512x512。更大的尺寸（如512px）意味着每个瓦片文件更大，加载次数少但每次传输数据量多。需要根据网络环境和性能要求进行测试选择。
-   **如何避免瓦片间的裂缝？** 在切片时，相邻瓦片边界处的高程值必须保持一致。一些先进的切片算法会对DEM数据的包围盒进行外延，确保切割后相邻瓦片在边界处有重叠像素或共用高程值，从而在渲染时无缝拼接。

### 瓦片金字塔模型
![alt text](WorldWind切片及文件组织示意.png)  
![alt text](瓦片金字塔模型.png)  
![alt text](不同金字塔层级的包含关系.png)  
WorldWind切片及文件组织示意说明:  
1. 经纬度切片数量比例2:1，经度方向瓦片数量是纬度方向的2倍，这是为了保持瓦片大小一致，避免经度方向的瓦片过宽，纬度方向的瓦片过窄
2. 0层瓦片大小(Level zero tile size)：lzts,36°，分了10*5格，所以每个像素代表36°经纬范围
3. 这个其实是按照度数均分的，但实际上经纬度对应的地理范围不一样，是不是导致瓦片对应的地理范围的长度南北跟东西方向不一致?
4. 切片金字塔从高到低 从上到下 金字塔层级从小到大 切片数量从少到多 分辨率从低到高 地球从缩小到放大 视角从高到低，都是一个概念、不同说法，是正金字塔


瓦片金字塔层级对应->地球缩放级别->对应视角高度,实际观察时，缩放地球或者调整视角高度，LOD调度策略会自动切换瓦片层级，以适应当前视角的细节需求，然后根据瓦片层级，从瓦片金字塔中加载对应层级(Z)的瓦片数据(X,Y)，再根据瓦片坐标，从瓦片文件中读取瓦片数据，最后将瓦片数据转换为三维模型(顶点、法线、纹理坐标等)进行渲染，从而实现动态的3D地形展示。

### 瓦片切割

地图切片主要是一个经纬度与瓦片坐标之间的坐标变换问题以及图片的降采样问题

瓦片切片制作过程[gdal瓦片构建过程api](gdal瓦片构建过程api.pdf)
1. 经纬度与瓦片坐标的转换，[地图切片-经纬度-瓦片坐标相互转换](地图切片-经纬度-瓦片坐标相互转换.pdf)
   1. 对于一张投影地图，坐标变换如下
      1. 经纬度->米
      2. 米->像素坐标
      3. 像素坐标->瓦片坐标
   2. 对于三维地图应该直接按照视角高度确定金字塔层级z，根据经纬度确定x y
2. 图片的降采样 生成图像金字塔 金字塔构建过程从最高精度(原始dem，金字塔底部)开始，不断下采样得到各层级的瓦片数据，最低分辨率的瓦片数据对应金字塔的最高(上)部分/顶部，是0级瓦片
3. 将每个瓦片对应的256*256的图片按照一定规则存储起来 便于可视化时读取响应瓦片
4. LOD调度策略
   - 金字塔结构与四叉树：这是LOD的基础。系统会预先为模型或地形生成多个细节层级的数据，像金字塔一样堆叠。
   - 在实时渲染时，常使用四叉树（用于地形）或八叉树（用于体数据）这类数据结构来高效管理这些层级，实现快速的空间查找和细节检索。
   - 瓦片化与分页调度：对于海量数据（如全球地形），数据会被切割成小块（瓦片）。系统不会一次性加载所有数据，而是根据视点动态地加载（Page In）所需瓦片，并卸载（Page Out）不可见或距离较远的瓦片，确保内存中只维持一个可控的数据集。开源引擎OSG中的 osgDB::DatabasePager组件就是实现分页调度的典型例子 

- [x] 具体的切片过程 gdal库  https://juejin.cn/post/7126890155273060382
- [x] 每层金字塔层级的瓦片数量: 由原始dem数据的地理范围、金字塔层级和瓦片地理大小共同决定，瓦片图像的大小默认都是256x256或512x512
- [x] 瓦片层级与地图比例尺关系 取决于以下几个核心因素：
        投影坐标系： 绝大多数在线瓦片地图（如Google Maps、OpenStreetMap、Bing Maps、高德、百度等）使用的是 Web墨卡托投影。
        初始分辨率： 在层级 z=0 时，整个世界通常被表示为一个256x256像素的瓦片。这个层级下地图覆盖整个地球的宽度（赤道周长）所对应的像素距离，就是初始分辨率的基础。
        瓦片金字塔结构： 每增加一个层级 (z+1)，地图的详细程度翻倍，每个瓦片覆盖的地理范围缩小为上一层级瓦片的四分之一（长宽各缩小一半）。同时，该层级下地图的像素分辨率（每像素代表的地理距离）也变为上一层级的一半。
        屏幕分辨率： 地图最终显示在屏幕上，屏幕的物理DPI会影响用户感知的“比例尺”。在线地图系统通常采用一个标准屏幕分辨率（如96 DPI）来计算和定义其标称比例尺。

### 瓦片金字塔与mipmap
地图瓦片的金字塔层级（LOD）和OpenGL的Mipmap层级，虽然都叫“层级”，也都用了“金字塔”结构，但它们在核心目标和技术实现上有着本质的区别。为了让你快速把握全貌，下面这个表格清晰地对比了它们的核心特性。

| 对比维度 | **地图瓦片金字塔层级 (LOD)** | **OpenGL Mipmap层级** |
| :--- | :--- | :--- |
| **核心目标** | **数据组织与网络调度**：将海量地理数据分层分块，实现按需加载，优化传输效率。 | **视觉质量与渲染性能**：解决纹理缩小渲染时的锯齿、闪烁问题，提升画面平滑度。 |
| **应用场景** | WebGIS、在线地图（如谷歌地图、百度地图）。 | 3D游戏、实时三维渲染、所有使用纹理贴图的图形应用。 |
| **数据结构** | **瓦片金字塔**：每个层级是无数张覆盖不同地理范围的独立图片（瓦片）。 | **纹理金字塔**：同一张纹理的一系列分辨率逐级减半的图像副本。 |
| **层级定义** | 层级（Level/Z）与地图的**比例尺/缩放级别**挂钩。层级越高，地图越详细，瓦片数量也呈指数级增长。 | 层级（Level）与纹理自身的**分辨率**挂钩。Level 0是原始分辨率，每增一级，宽高减半。 |
| **驱动因素** | 由用户的**地图操作**驱动（如缩放、平移）。系统根据当前视口的缩放级别和范围计算需要加载哪些瓦片。 | 由**像素与纹素的映射关系**驱动。GPU实时计算一个屏幕像素覆盖了多少纹理像素，自动选择合适的Mipmap层级。 |
| **切换策略** | **离散切换**：缩放时，在不同层级的瓦片之间进行“硬切换”。 | **平滑过渡**：可通过三线性过滤等技术，在两个相邻Mipmap层级之间进行混合，实现平滑过渡。 |
| **性能关注点** | **网络带宽和磁盘I/O**：重点在于减少不必要的瓦片请求和传输延迟。 | **GPU计算和显存访问**：重点在于提高纹理缓存命中率，减少渲染卡顿。 |

#### 💡 深入理解差异

##### 🗺️ 地图瓦片LOD：一种“宏观”的数据管理策略
地图瓦片技术本质上是一种应对海量地理数据的管理和传输方案。
*   **核心要解决的问题是“数据量太大”**。无法将整个地球的高清地图一次性加载到浏览器中。
*   其解决方案是“**化整为零，分层处理**”。通过预先生成不同缩放级别（对应不同详细程度）的地图图片，并将每个级别的地图切割成无数个标准大小的瓦片（如256x256像素）。当用户浏览地图时，客户端只会请求当前视野和缩放级别下所需的少量瓦片，然后像拼图一样在浏览器中拼接起来。这极大地减轻了服务器压力和网络传输负担。

##### 🎨 OpenGL Mipmap：一种“微观”的渲染优化技术
Mipmap技术则专注于解决实时图形渲染中一个具体的视觉问题：**纹理缩小**。
*   **核心要解决的问题是“视觉瑕疵”**。当一个高分辨率纹理被应用到远处一个在屏幕上只占几个像素的物体上时，GPU为了确定这个像素的颜色，需要从巨大的纹理中采样。由于采样不足，会导致严重的锯齿和闪烁现象。
*   其解决方案是“**预先过滤，按需取样**”。GPU会预计算并存储纹理的一系列缩小版本。当物体离得远时，就不再从原始大纹理中采样，而是从一个尺寸匹配的小纹理中采样，这样每个屏幕像素都能获得更具代表性的纹理颜色平均值，从而有效消除闪烁和锯齿，得到更平滑的视觉表现。

#### 🛠️ 实践中的协同与选择
尽管目标不同，但在复杂的三维地理信息系统（如Cesium、Mapbox GL JS等）中，这两种技术经常协同工作。
*   **地形渲染**：地形本身作为三维网格，会使用瓦片金字塔来管理不同区域的几何细节（几何LOD）。而贴在地形上的影像或地貌纹理，则会使用Mipmap技术来确保其在远处渲染时的平滑度。
*   **性能与质量平衡**：对于Mipmap，开发者可以通过选择不同的过滤模式来平衡性能和质量，例如，`GL_LINEAR_MIPMAP_NEAREST` 是性能和质量的良好折衷，而 `GL_LINEAR_MIPMAP_LINEAR`（三线性过滤）能提供最平滑的过渡效果。

#### 💎 总结
简单来说，**地图瓦片LOD决定了“加载哪张地图”，而OpenGL Mipmap决定了“如何画好一个表面”**。前者是面向数据和网络的地理空间概念，后者是面向渲染和视觉的计算机图形学概念。理解这一根本区别，有助于你在各自的领域内更好地应用这些强大的优化技术。

主要区别:
1. 数据结构：瓦片金字塔每一层级是无数张相同尺寸(256*256)的独立图片组成，而Mipmap每一层级是同一张图片的分辨率逐级减半的图像副本
2. 层级定义：瓦片金字塔层级与地图比例尺/缩放级别挂钩，层级越高，地图越详细，瓦片数量也呈指数级增长；Mipmap层级与纹理自身的分辨率挂钩，Level 0是原始分辨率，每增一级，宽高减半，层级数值正好相反


## GIS数据可视化相关技术
### 2d 可视化
dem
dom

### 3d 可视化

佐罗中的名称 代码对应的变量名 及可能的gis术语
1. qgis中的vertical scale可以修改地形的起伏比例
2. skirt height 裙摆(边)高度,(佐罗叫接缝缩放)
   gis可视化时，会将dem切片成多层级的地形瓦片，使用LOD技术加载指定瓦片,这会导致几个问题:  
   1. 不同层级瓦片高程采样精度不同，边缘点高程值可能不一样
   2. 渲染精度有限，gpu处理大量瓦片时，浮点运算精度有限，瓦片边缘位置计算可能有偏差
   3. 垂直缩放影响，垂直缩放>1时，地形起伏被放大，微小的地形差异可能会被放大为明显的瓦片间隙
   
   通过在每个地形瓦片的边缘生成一圈垂直向下延伸的 “虚拟墙”（裙边），用于遮盖瓦片之间因渲染或高程计算产生的微小间隙，从而实现无缝拼接的效果。
   主要解决的的问题场景:  
   1. 瓦片间隙:3D 视图中可见地形表面有黑色 / 白色裂缝，尤其在地形起伏大、垂直比例高时，裂缝会显得更加明显。
   2. 瓦片边缘闪烁:旋转 / 缩放 3D 视图时，瓦片边缘出现 “闪烁” 或 “镂空” 效果
   3. 高低分辨率瓦片衔接:不同 LOD 层级的瓦片交界处出现明显断层
   4. 地形与其他3d对象(建筑物)衔接:地形与 3D 模型底部之间有微小间隙
3. min render lod/max render lod/lod distance
   min render lod（最小渲染细节层次）、max render lod（最大渲染细节层次）、lod distance factor（细节层次距离系数），它们决定了地形 / 模型在不同距离下的显示精度与渲染效率

   **这个min max好像反了，反正看定义吧，貌似网页gis从 “顶层（小比例尺）” 到 “底层（大比例尺）” 的层级数量，如在线地图通常设计 20-22 个层级（Zoom 0 至 Zoom 21），Zoom 0 为全球范围（1 块瓦片），Zoom 21 为厘米级精度；知道这个事就可以了**

   - 在 GIS 三维渲染（如 QGIS 3D、ArcGIS Pro 3D、Cesium 等）中，LOD（Level of Detail，细节层次） 技术是平衡渲染效果与性能的核心机制。以下三个参数共同控制 LOD 的行为：min render lod（最小渲染细节层次）、max render lod（最大渲染细节层次）、lod distance factor（细节层次距离系数），它们决定了地形 / 模型在不同距离下的显示精度与渲染效率。
  
   - 一、核心概念：LOD 技术基础
      LOD 的核心思想是：物体离视点越近，使用越高细节的模型渲染；离视点越远，使用越低细节的模型渲染，从而在保证视觉效果的同时显著降低 GPU 计算负载。
      在 GIS 地形渲染中，LOD 通常表现为：
      瓦片金字塔结构：DEM 数据被预先生成多个分辨率层级（如原始 30m→60m→120m→240m 等）QGIS
      动态切换机制：渲染引擎根据相机与地形瓦片的距离，自动选择最合适的 LOD 层级进行渲染
      误差控制：通过控制 LOD 切换阈值，确保相邻层级切换时的视觉差异在人眼可接受范围内
   - 二、参数详解：定义、原理与作用
     1. min render lod（最小渲染细节层次）
      定义
      渲染引擎允许使用的最高细节层级（**通常 LOD 值越小，细节越高 貌似也反了**），表示相机靠近时能显示的最精细地形 / 模型效果。
      原理
      LOD 层级编号规则：通常LOD 0 = 原始分辨率（最高细节），LOD 1=1/2 分辨率，LOD 2=1/4 分辨率，依此类推，数值越大细节越低。
      min render lod 限制了渲染的 “上限”，即使相机无限靠近，也不会使用比该值更低的 LOD 层级（即不会显示比该层级更精细的细节）。
      作用与应用场景
      作用	应用场景	典型值
      保证近距离视觉精度	地形精细建模、工程勘测、三维测量	0（原始分辨率）
      限制最大渲染负载	低性能设备、大范围场景浏览	1-2（降低最高细节需求）
     统一渲染标准	多用户协作场景，确保所有人看到相同最高细节	固定值（如 0 或 1）
     2. max render lod（最大渲染细节层次）
      定义
      渲染引擎允许使用的最低细节层级（通常 LOD 值越大，细节越低），表示相机远离时能显示的最简化地形 / 模型效果。
      原理
      当相机距离地形瓦片超过一定阈值时，渲染引擎会逐步切换到更高 LOD 层级（更低细节），直到达到 max render lod 限制。
      超过 max render lod 的瓦片通常会被完全隐藏（不渲染），以进一步优化性能。
      作用与应用场景
      作用	应用场景	典型值
      控制渲染范围	避免渲染过远、人眼无法分辨的地形细节	6-8（适用于全球 / 大范围场景）
      优化性能	高负载场景，强制远处地形使用最低细节	4-5（平衡范围与性能）
      避免视觉噪声	低对比度地形，远处低细节可减少不必要的纹理干扰	3-4
     3. lod distance factor（细节层次距离系数）
      定义
      控制 LOD 层级切换距离的缩放因子，**用于调整 LOD 切换的 “敏感度”**，决定了不同 LOD 层级在多远距离时发生切换。
      原理
      基础切换距离计算公式：切换距离 = 基准距离 × lod distance factor
      系数 > 1 → 延迟 LOD 切换（物体在更远距离才会降低细节），视觉效果更好但性能开销更大
      系数 < 1 → 提前 LOD 切换（物体在更近距离就降低细节），性能更好但视觉效果可能下降
      作用与应用场景
      作用	应用场景	典型值
      平衡性能与效果	大多数通用场景	1.0（默认值）
      提升视觉质量	高质量可视化、演示场景	1.5-2.0（延迟切换）
      极端性能优化	低配置设备、大规模场景	0.5-0.8（提前切换）
      场景捕捉优化	反射 / 倒影渲染，降低次要视图的 LOD 需求	2.0+（加速渲染）
   - 三、参数协同工作机制
      三个参数共同构成 LOD 渲染的 “控制三角”，其工作流程如下：
      初始化：渲染引擎加载 DEM 的 LOD 金字塔（从 min render lod 到 max render lod）
      距离计算：实时计算每个地形瓦片与相机的距离
      LOD 选择：
      根据距离 × lod distance factor确定理论 LOD 层级
      确保选择的层级在min render lod ≤ 层级 ≤ max render lod范围内
      渲染执行：加载并渲染选定 LOD 层级的瓦片
      动态更新：相机移动时重复步骤 2-4，实现 LOD 的平滑切换
      关键关系：
      min render lod ↔ max render lod：定义了 LOD 的可用范围，范围越大，渲染灵活性越高，但内存占用也越大
      lod distance factor ↔ 切换距离：系数直接影响 LOD 切换时机，是平衡性能与视觉效果的关键调节点
      三者联动：调整其中一个参数时，通常需要同步调整另外两个以保持整体平衡
   - 四、GIS 软件中的实际应用（以 QGIS 3D 为例）
      在 QGIS 3D 地形渲染中，LOD 参数通常在以下位置设置：
      打开 3D Map View → 点击⚙️【Configure...】→【Terrain】选项卡
      高级设置：【Settings】→【Options】→【3D】→【Rendering】
      常见配置场景与参数建议
      场景	min render lod	max render lod	lod distance factor	备注
      精细地形建模	0	4	1.2	近距离观察地形细节，如滑坡分析、建筑选址
      大范围地形浏览	1	8	0.8	查看省级 / 国家级地形，优先保证流畅性
      低性能设备	2	6	0.7	降低整体渲染负载，避免卡顿
      演示 / 可视化	0	6	1.5	提升视觉效果，延迟 LOD 切换，减少明显的细节突变
      注意事项与最佳实践
      避免 “范围过大”：max render lod - min render lod > 8 可能导致内存溢出，尤其在处理高分辨率 DEM 时
      与垂直比例联动：垂直比例 > 1 时，地形起伏被放大，建议适当降低 lod distance factor（如 0.8），避免远处地形细节丢失过多
      结合裙边高度（Skirt height）：LOD 层级切换可能导致瓦片间隙，需同步调整 Skirt height 参数消除裂缝（详见之前问答）
      测试驱动优化：先设置默认值（min=0, max=6, factor=1.0），再根据实际渲染效果与性能逐步调整
   - 五、常见误区与问题排查
      误区 1：“min render lod 设为 0 一定最好”
      错误：在低性能设备上，强制使用最高细节可能导致严重卡顿，应根据设备性能合理设置
      误区 2：“lod distance factor 越大越好”
      错误：过大的系数会导致远处地形仍使用高细节，增加 GPU 负担，可能出现帧率骤降
      问题排查：LOD 切换时出现明显 “跳变”
      解决：① 减小 lod distance factor，让切换更平缓；② 增加 LOD 层级数量，缩小相邻层级的细节差异；③ 启用 LOD 过渡效果（部分 GIS 软件支持）
      问题排查：远处地形消失
      解决：增大 max render lod 值，扩大 LOD 可用范围，或降低 lod distance factor，让地形在更远距离才切换到最低细节
   - 六、总结
      min render lod、max render lod、lod distance factor是 GIS 三维渲染中控制 LOD 行为的核心参数，它们分别定义了渲染的细节上限、细节下限和切换敏感度。理解三者的原理与协同工作机制，能帮助你在不同场景下找到 “效果 - 性能” 的最佳平衡点，实现流畅且高质量的 GIS 三维可视化。
      需要我根据你的具体 GIS 软件（如 QGIS/ArcGIS Pro/Cesium）和使用场景（精细建模 / 大范围浏览 / 低性能设备），给出一套可直接套用的 LOD 参数配置吗？只需告诉我软件名称和主要用途即可。

# GIS 工具链
地理信息（GIS）的工具链是一个分层协作的"全家桶"——**没有任何一个工具能包打天下**，通常是最底层的 C/C++ 库 + Python 数据处理层 + 桌面 GIS + 空间数据库 + Web 服务/前端 各司其职。下面按层梳理主流工具，最后给你一套"够用起步组合"。

## 一、底层核心库（C/C++，几乎所有上层工具的基石）

这几个是"地基"，你可能不直接调用，但你用的每个 GIS 工具背后都有它们：

- **GDAL / OGR**：地理空间数据抽象库，栅格+矢量读写、格式转换、重投影的"万能翻译器"，几乎所有 GIS 工具的底层依赖
- **PROJ**：坐标参考系（CRS）与基准面转换引擎，处理不同椭球体/投影间的换算
- **GEOS**：OGC 简单要素规范的几何引擎，缓冲区、相交、并集等拓扑运算的核心，PostGIS / Shapely / QGIS 全靠它
- **SFCGAL**：在 GEOS 基础上扩展 3D 几何运算和高级空间 SQL
- **JTS**（Java）：GEOS 的 Java 原生等价物，Java GIS 生态的地基
- **PDAL**：点云版的 GDAL，处理 LAS/LAZ 激光雷达数据

> 💡 记住一个事实：**GDAL + PROJ + GEOS 是"地理信息界的三件套"**，几乎 90% 的开源 GIS 软件都链接它们。

## 二、Python 数据处理生态（最活跃的一层）

这是当下地理信息处理的主战场，以 **GeoPandas 为中心** 串起整个生态：

| 库 | 角色 | 底层依赖 |
|---|---|---|
| **GeoPandas** | 矢量数据的 DataFrame 操作，空间连接/叠加/缓冲 | Shapely + Fiona + PyProj |
| **Shapely** | 几何对象操作（点线面创建、buffer、intersection） | GEOS |
| **Fiona** | 矢量文件读写（Shapefile / GeoJSON / GPKG） | GDAL/OGR |
| **Pyogrio** | 比 Fiona 更快的矢量 I/O，Arrow 风格 | GDAL |
| **Rasterio** | 栅格(GeoTIFF)读写与窗口操作 | GDAL |
| **Rioxarray** | Rasterio + Xarray，多维栅格/时序数据 | Rasterio + Xarray |
| **PyProj** | 坐标系变换 | PROJ |
| **Rtree** | 空间索引，加速邻域查询 | libspatialindex |
| **rasterstats** | 分区统计（zonal statistics） | Rasterio + Shapely |
| **GeoAlchemy2** | 通过 SQLAlchemy ORM 操作 PostGIS | — |
| **OWSLib** | 连接 WMS / WFS / WCS 等 OGC 服务 | — |
| **Folium** | 在 Jupyter 里快速生成 Leaflet 交互地图 | Leaflet.js |
| **Cartopy** | 科学绘图，支持各种投影 | PROJ + Matplotlib |
| **PySAL** | 空间统计分析、空间计量经济学 | — |

> 📌 GeoPandas 官方明确：它本身不是从零造轮子，而是把 pandas + Shapely + Fiona + PyProj 这四件套"粘"成一个好用的 DataFrame 接口。所以学 GeoPandas 实质上学的是这一整套。

## 三、桌面 GIS（图形化操作）

- **QGIS**：开源桌面 GIS 旗舰，3.x 系列持续迭代，支持栅格/矢量/3D/时态数据，Processing 工具箱可调用 GRASS、SAGA、GDAL 算法，插件生态庞大。配 **QField** 可做移动端野外采集
- **GRASS GIS**：科学级地理分析，地形/水文/插值模型强
- **SAGA GIS**：地形分析、水文、地统计、栅格处理见长
- **WhiteboxTools / Whitebox GAT**：地形分析、遥感、水文建模，科研圈常用
- **gvSIG**：带 CAD 式工具和 3D 能力的桌面 GIS
- **uDig**：轻量桌面 GIS，Web 服务集成友好

> 💡 QGIS 的 Processing 工具箱可以直接调用 GRASS / SAGA / WhiteboxTools 的算法——所以装一个 QGIS，等于拥有了多个分析引擎的统一入口。

## 四、空间数据库（数据存储与查询）

- **PostGIS**：PostgreSQL 的空间扩展，行业标杆。支持几何/地理类型、GiST 空间索引、ST_* 函数库、3D、拓扑、栅格、轨迹分析
- **pgRouting**：PostGIS 上的路由扩展，最短路径、车辆路径问题（VRP）
- **Spatialite**：SQLite 的空间扩展，单机文件型空间数据库
- **H2GIS**：Java H2 数据库的空间扩展

## 五、Web 服务与地图发布（服务器端）

- **GeoServer**（Java）：OGC 服务发布旗舰，支持 WMS / WFS / WCS / WMTS / OGC API，数据后端可接 PostGIS、GeoPackage 等，SLD 样式驱动
- **MapServer**（C）：老牌地图服务，性能优秀，对 OGC API 支持完善
- **TileServer GL / MapProxy**：瓦片服务与缓存代理

## 六、Web 前端可视化（JavaScript）

- **Leaflet**：轻量、移动端友好，插件生态极其丰富，适合快速搭交互地图
- **OpenLayers**：功能全面，投影控制、矢量瓦片、交互逻辑都可深度定制，适合复杂企业应用
- **MapLibre GL**：开源的 WebGL 矢量地图库（Mapbox GL JS 的开源分支），GPU 渲染、三维地形
- **Deck.gl**：GPU 加速的大数据地理可视化图层
- **Kepler.gl**：基于 Deck.gl 的高层封装，适合快速做大规模时空数据可视化

## 七、瓦片 / 地形 / OSM 处理命令行工具

- **Tippecanoe**：GeoJSON/CSV → 矢量瓦片（MBTiles/PMTiles），Felt 出品
- **Planetiler**：Java 实现，全球级 OSM 数据超快生成矢量瓦片
- **Tilemaker**：从 OSM PBF 直接生成矢量瓦片
- **gdaldem**：地形分析（山体阴影、坡度、坡向、色彩渲染）
- **Cesium Terrain Builder (ctb-tile)**：DEM → Cesium 量化网格地形瓦片
- **osmium-tool / osmfilter / Overpass API**：OSM 数据处理与查询

## 八、遥感与摄影测量

- **ESA SNAP**：欧空局官方遥感处理平台
- **Orfeo Toolbox (OTB)**：光学遥感影像分析
- **OpenDroneMap**：无人机航拍 → 正射影像/点云/3D 模型
- **eo-learn**：基于 Python 的地球观测机器学习框架

## 九、典型开源技术栈（替代 ArcGIS 的组合）

如果你想用纯开源方案覆盖 ArcGIS 全家族的功能，业界验证过的组合是：

```
桌面分析：     QGIS  (+ GRASS, SAGA, WhiteboxTools 通过 Processing 调用)
数据转换/批处理： GDAL/OGR 命令行
空间数据库：   PostGIS (+ pgRouting)
Web 服务发布：  GeoServer 或 MapServer
前端可视化：    Leaflet / OpenLayers / MapLibre GL
Python 自动化： GeoPandas + Rasterio + Shapely + PyProj
```

这套组合能覆盖 ArcGIS Pro + ArcToolbox + Enterprise Geodatabase + ArcGIS Server 的大部分功能，且零授权费。

---

## 怎么选：按你的角色

- **🐍 Python 数据分析 / 自动化处理** → 装 `geopandas` 这一个包，它自动拉起 Shapely/Fiona/PyProj/Rasterio 全套依赖（conda 安装最省心）。再加 `pyogrio` 提速矢量读写
- **🖥️ 桌面可视化与交互分析** → **QGIS** 是唯一答案
- **🗄️ 团队共享 / Web 后端 / 大规模查询** → **PostGIS**
- **🌐 发布 Web 地图服务** → **GeoServer**
- **🗺️ 前端做网页地图** → 轻量用 **Leaflet**，复杂用 **OpenLayers**，WebGL 三维用 **MapLibre GL**
- **🛰️ 遥感影像处理** → **Rasterio**（Python 轻量）+ **ESA SNAP**（重型）
- **⛰️ 地形/水文建模** → **WhiteboxTools** 或 **GRASS GIS**

> ⚠️ **新手最容易踩的坑**：以为装了 GeoPandas 就能直接用。其实 GeoPandas 依赖 GDAL/GEOS/PROJ 这些 C 库，**强烈建议用 `conda install -c conda-forge geopandas`** 一次性装齐，别用裸 `pip`，否则 Windows 下 90% 会卡在 GDAL 编译上（这个问题在上轮 GDAL 回答里详细讲过）。

你目前是想做**矢量数据分析、遥感栅格处理、WebGIS 发布，还是桌面制图**？告诉我具体方向，我可以给你更精准的"最小可用工具组合"和安装命令。

# ZORRO engine
1. global mapper地理信息浏览及处理,包括DOM卫片 MAP2021地面分类 DEM高程，都是tif格式
2. photoshop
3. cityengine参数化城市建模
4. maya 3d建模
5. notepad++
6. speedtree 树参数化建模

## 地形数据获取及处理
1. 所需数据分类 ![alt text](地形数据类型.png) **是什么**
   1. 高精度dem(高程)
   2. 不同精度dom(影像)
   3. shp矢量数据(河流 道路)
   4. osm建筑轮廓
   5. 地类分类数据
2. 数据获取途径
   1. 水经注 watermap中国版global mapper，地图下载 数据处理 制图，可以从谷歌地图 天地图 osm等多种在线地图源下载影像 地形等数据，一般用于快速获取区域地图背景、下载卫星图、在线地图转离线等
   2. global mapper在线数据下载，瑞士军刀，支持超过300种空间数据导入、导出、查看、编辑、分析，包括LiDAR点云处理
	地形分析、路径剖面、体积计算等，格式兼容性及数据处理效率著称，不如esri的arcgis企业级空间数据库，但日常gis处理足够了，用于格式转换、点云分类、生成DEM、基础空间分析、地图制作
   3. esri Landcover数据集 livingatlas.arcgis.com，基于哨兵-2的卫星影像，分割得到地表分类数据，将地球表面的每个像素分类为水体、树木、草地、农作物、建筑表面、裸地等，每年更新免费获取，是了解地表覆盖变化的重要数据源，一般用于城市规划、环境监测、气候变化研究、农业调查
   4. osm建筑轮廓数据 www.openstreetmap.org 开源、可自由编辑的全球地图数据库，包含道路、建筑、河流、兴趣点、土地利用等丰富的地理要素的矢量地图数据，一般作为底图、路径规划、gis分析的数据源，制作专题图
   5. aster全球30m精度DEM数据集 gdemdl.aster.jspacesystems.or.jp，主要提供全球数字高程模型GDEM，免费覆盖全球，一般用于生成地形图、地貌分析、水文分析、作为遥感影像用于地物分类等
3. 数据处理
   1. 坐标系投影转换geo graphics或者Mercator投影，基准WGS84
   2. 数据裁剪
   3. 数据导出
4. 佐罗引擎编辑器使用流程
   1. dem导入
   2. dom导入
   3. mask导入
   4. 植被导入
   5. 城市建筑物生成及导入
   6. 地表建筑物制作及导入
   7. 数据库迭代处理
5. 地形 植被的brush画刷，不如ps好用 学习ps
6. lightmap没有地理信息，需要在global mapper里校正一下
   
## 模型得归零，tga贴图不支持

# 作战仿真平台
四大作战仿真平台：CIMPro、AFSim、VR-Forces与EADSIM
CIMPro采用"空天地一体化"设计理念，内置全球地理信息系统，支持19级影像瓦片和15级高程数据 国产
AFSIM:美国空军研发
VR-Forces：沉浸式训练先锋
EADSIM：防空反导专业平台

Open Source GeoSpatial Foundation:旗下有很多开源库  
gdal:Geospatial data abstraction library,支持很多种数据及格式的读写，可以看看doc GDALGeoTransform GDALDataset  
proj:a generic coordinate transformation software that transforms geospatial coordinates from one coordinate reference system (CRS) to another  
grass:Geographic resource analysis support system  
osgeo


# gis 网站
https://earthengine.google.com/
https://www.earthdata.nasa.gov/