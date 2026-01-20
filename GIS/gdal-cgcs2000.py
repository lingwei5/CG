# 作者：GIS小砖家
# 链接：https://zhuanlan.zhihu.com/p/11941884883
# 来源：知乎
# 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。

import requests
import os
import random
import math
from PIL import Image
import io
from osgeo import osr
from osgeo import gdal
import copy
import numpy as np
from PIL import Image
import shapefile
from pyproj import CRS
from pyproj import Transformer

Image.MAX_IMAGE_PIXELS = 800000000


agents = [
    'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36',
    'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/532.5 (KHTML, like Gecko) Chrome/4.0.249.0 Safari/532.5',
    'Mozilla/5.0 (Windows; U; Windows NT 5.2; en-US) AppleWebKit/532.9 (KHTML, like Gecko) Chrome/5.0.310.0 Safari/532.9',
    'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/534.7 (KHTML, like Gecko) Chrome/7.0.514.0 Safari/534.7',
    'Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US) AppleWebKit/534.14 (KHTML, like Gecko) Chrome/9.0.601.0 Safari/534.14',
    'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.14 (KHTML, like Gecko) Chrome/10.0.601.0 Safari/534.14',
    'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.20 (KHTML, like Gecko) Chrome/11.0.672.2 Safari/534.20',
    'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/534.27 (KHTML, like Gecko) Chrome/12.0.712.0 Safari/534.27',
    'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/13.0.782.24 Safari/535.1']


def getImg(url, save_path):
    
    header={
        'User-agent':random.choice(agents),        
        }
    try:
        result=requests.get(url,headers=header)
        if result.status_code!=200:
            print('请求失败！')
            return
    except Exception as e:
        print(e)
        return
        
    image = Image.open(io.BytesIO(result.content))

    image.save(save_path,'PNG')


# 经纬度反算切片行列号  4490坐标系
def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** (zoom-1)       #此处要注意，初始化zoom等级为0还是1
    xtile = int((lon_deg + 180.0)*n /180)
    ytile = int((90-lat_deg) * n/180)
    return (xtile, ytile)


def read_img(filename):
    dataset=gdal.Open(filename)       #打开文件

    im_width = dataset.RasterXSize    #栅格矩阵的列数
    im_height = dataset.RasterYSize   #栅格矩阵的行数

    im_geotrans = dataset.GetGeoTransform()  #仿射矩阵
    im_proj = dataset.GetProjection() #地图投影信息
    im_data = dataset.ReadAsArray(0,0,im_width,im_height) #将数据写成数组，对应栅格矩阵

    del dataset 
    return im_proj,im_geotrans,im_data,im_width,im_height

#写文件，以写成tif为例
def write_img(filename,im_proj,im_geotrans,im_data):
    #gdal数据类型包括
    #gdal.GDT_Byte, 
    #gdal .GDT_UInt16, gdal.GDT_Int16, gdal.GDT_UInt32, gdal.GDT_Int32,
    #gdal.GDT_Float32, gdal.GDT_Float64

    #判断栅格数据的数据类型
    if 'int8' in im_data.dtype.name:
        datatype = gdal.GDT_Byte
    elif 'int16' in im_data.dtype.name:
        datatype = gdal.GDT_UInt16
    else:
        datatype = gdal.GDT_Float32

    #判读数组维数
    if len(im_data.shape) == 3:
        im_bands, im_height, im_width = im_data.shape
    else:
        im_bands, (im_height, im_width) = 1,im_data.shape 

    #创建文件
    driver = gdal.GetDriverByName("HFA")            #数据类型必须有，因为要计算需要多大内存空间
    dataset = driver.Create(filename, im_width, im_height, im_bands, datatype)
    
    
    dataset.SetGeoTransform(im_geotrans)              #写入仿射变换参数
    dataset.SetProjection(im_proj)                    #写入投影

    if im_bands == 1:
        dataset.GetRasterBand(1).WriteArray(im_data)  #写入数组数据
    else:
        for i in range(im_bands):
            dataset.GetRasterBand(i+1).WriteArray(im_data[i])

    del dataset

#图像合并拼接
def merge_png(size,xmin,xmax,ymin,ymax,path,result_path):

    xcount=xmax-xmin+1
    ycount=ymax-ymin+1
    joint=Image.new('RGB', (size*xcount,size*ycount))
    for i in range(ycount):
        for j in range(xcount):
            dir=os.path.join(path,str(xmin+j))
            name='%d.png'%(ymin+i)
            inpath=os.path.join(dir,name)
            img=Image.open(inpath)
            loc=(j*size,i*size)
            joint.paste(img,loc)

    joint.save(result_path)


#为图像定义坐标系
def define_coord(lu_x,lu_y,rd_x,rd_y,inpath,outpath):
    proj,geotrans,data,im_width,im_height = read_img(inpath)
    #print(proj)
    #print(geotrans)
    #print(data)
    #print(im_width,im_height)

    #设置输出图像的坐标  
    dstSRS=osr.SpatialReference()  
    dstSRS.ImportFromEPSG(4490)
    #print outTrans  
    dstSRS_wkt=dstSRS.ExportToWkt()
    #左上角坐标
    OriginLX_src=geotrans[0]
    OriginUY_src=geotrans[3]

    #每个项目代表的距离
    pixl_w_src=geotrans[1]  
    pixl_h_src=geotrans[5]  
    #右下角坐标  
    OriginRX_src=OriginLX_src+pixl_w_src*im_width  
    OriginBY_src=OriginUY_src+pixl_h_src*im_height  

    

    #每个像素代表的距离
    pixl_w_dst=(rd_x-lu_x)/im_width
    pixl_h_dst=(rd_y-lu_y)/im_height

    #定义转换信息
    geotrans=(lu_x,pixl_w_dst,0,lu_y,0,pixl_h_dst)

    write_img(outpath,dstSRS_wkt,geotrans,data) #写数据


def download(root_path,z,xmin,xmax,ymin,ymax):

    for x in range(xmin, xmax+1):
        for y in range(ymin, ymax+1):
            print(y)
            
            #修改此处tilepath
            tilepath = 'http://**********/'

            zoom_path=os.path.join(root_path,str(z))
            if not os.path.exists(zoom_path):
                os.makedirs(zoom_path)
            path = os.path.join(zoom_path,str(x))
            if not os.path.exists(path):
                os.makedirs(path)
            getImg(tilepath, os.path.join(path, str(y) + ".png"))

if __name__=='__main__':
    
    root_path = "./4490tile"
    if not os.path.exists(root_path):
        os.makedirs(root_path)
        
    for z in range(15,16):

        lefttop = deg2num(23.298267,112.772579, z)  # 下载切片的左上角角点,
        rightbottom = deg2num(22.715599,113.446634, z)  #右下角       ,
        xmin=lefttop[0]
        xmax=rightbottom[0]
        ymin=lefttop[1]
        ymax=rightbottom[1]

        print('download')
        download(root_path,z,xmin,xmax,ymin,ymax)
        merge_path=os.path.join(root_path,'merge.png')
        print('merge')
        merge_png(256,xmin,xmax,ymin,ymax,os.path.join(root_path,str(z)),merge_path)

        resolution=180.0/2**(z-1)    #此处要注意起始zoom等级是0还是1
        lng_min=-180+resolution*xmin
        lng_max=-180+resolution*(xmax+1)
        lat_max=90-resolution*ymin
        lat_min=90-resolution*(ymax+1)

        print('define_coord')
        out_path=os.path.join(root_path,'result.tif')
        define_coord(lng_min,lat_max,lng_max,lat_min,merge_path,out_path)