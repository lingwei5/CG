# GIS
Geographic Information System
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

表示数字高程模型的两种数据结构
   TIN网格 Triangulated Irregular Network TIN
   高程矩阵 grid 栅格

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

常见gis数据及其格式
1. .ter
2. .tif geotiff ![alt text](tif文件结构.png)
   TIFF (Tagged Image File Format) is not just an image format, but a kind of universal "container". Imagine that this is not an ordinary photograph, but a digital folder capable of storing a lot of information. TIFF can contain an image of the highest quality, as well as all the accompanying information about it: where and when it was taken, what parameters it has, what colors were used, and so on. Thanks to its flexible structure, TIFF is widely used where the quality and integrity of data are more important than the file size.
   1. Header. A small "business card" at the very beginning of the file. It tells the program that this is a TIFF and where to find basic information about the image.
   2. Directory (IFD). This is the "index" or "contents" of the file. It contains a list of all the characteristics of the image, described as "tags".类似dcm的tag，可以保存宽 高 颜色空间 压缩格式 相机参数 拍摄位置时间等等信息
   3. Pixel data. The actual image itself.
3. dom dem lightmap
4. 地类图map2021_aster，泥土 草 树，是mask文件，png
5. shape .shp文件


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

北京:东经115° 北纬40°

1. 常见坐标系
   1. 大地坐标系:定位地球上的点 用经度 纬度 高程表示 lambda phi h
	由于地球不是完美的椭球体 需要定义一个基准椭球体来表示地球
	事实上的标准是WGS84 World Geodetic System 1984,
		本初子午线(英国格林尼治天文台)以东或以西
		赤道(非洲赤道)以北或以南
		高程相对于 ​​WGS 84 椭球面​​的高度（单位：米）。请注意，这不同于我们常说的“海拔高”（相对于大地水准面）
   2. 地心地固直角坐标系:计算机内部计算
		原点在地球质心
		z轴指向北极
		x轴指向本初子午线与赤道的交点,即经度0 纬度0的点
		y轴指向东经90度
		xyz轴构成右手系
		xyz轴的单位是米
   3. 投影坐标系:在平面上展开地球
      1. Mercator投影:google地图 bing地图 OpenStreetMap等web地图服务底层都是墨卡托投影
		保持形状不变，等角投影, 但面积变形严重

GIS中的距离和角度
geodisc测地距离

# ZORRO engine
1. global mapper地理信息浏览及处理
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