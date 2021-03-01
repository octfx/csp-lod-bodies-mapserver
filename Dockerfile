FROM ubuntu:20.04

LABEL Description="CosmoScout VR LOD Bodies Map Server" maintainer="octfx" Version="1.0"
ENV TZ=Europe/Berlin

WORKDIR /tmp

# Download needed files
ADD https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73776/world.topo.bathy.200408.3x21600x10800.jpg /storage/mapserver-datasets/earth/bluemarble/bluemarble.jpg
ADD https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/raster/NE1_HR_LC_SR_W_DR.zip /tmp
ADD https://www.ngdc.noaa.gov/mgg/global/relief/ETOPO1/data/ice_surface/cell_registered/georeferenced_tiff/ETOPO1_Ice_c_geotiff.zip /tmp
ADD https://github.com/OSGeo/PROJ/releases/download/5.2.0/proj-5.2.0.zip /tmp

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone ;\
    apt-get update && \
    apt-get install -y apache2 \
                        apache2-bin \
                        apache2-utils \
                        cgi-mapserver \
                        mapserver-bin \
                        mapserver-doc \
                        libmapscript-perl \
                        libapache2-mod-fcgid \
                        unzip \
                        gdal-bin ;\
    a2enmod cgi fcgid ;\
    mkdir -p /storage/mapserver-datasets/earth/naturalearth \
    mkdir -p /storage/mapserver-datasets/earth/etopo1 \
    mkdir -p /storage/mapserver-datasets/earth/bluemarble ;\
    \
    \
    unzip /tmp/proj-5.2.0.zip && \
    cp /tmp/proj-5.2.0/nad/epsg /storage/mapserver-datasets;\
    \
    unzip /tmp/NE1_HR_LC_SR_W_DR.zip \
    cp /tmp/NE1_HR_LC_SR_W_DR.tif /storage/mapserver-datasets/earth/naturalearth/ORIGINAL_NE1_HR_LC_SR_W_DR.tif \
    gdal_translate -co tiled=yes -co compress=deflate /storage/mapserver-datasets/earth/naturalearth/ORIGINAL_NE1_HR_LC_SR_W_DR.tif /storage/mapserver-datasets/earth/naturalearth/NE1_HR_LC_SR_W_DR.tif \
    gdaladdo -r cubic /storage/mapserver-datasets/earth/naturalearth/NE1_HR_LC_SR_W_DR.tif 2 4 8 16; \
    \
    unzip /tmp/ETOPO1_Ice_c_geotiff.zip \
    cp /tmp/ETOPO1_Ice_c_geotiff.tif /storage/mapserver-datasets/earth/etopo1/ORIGINAL_ETOPO1_Ice_c_geotiff.tif \
    gdal_translate -co tiled=yes -co compress=deflate /storage/mapserver-datasets/earth/etopo1/ORIGINAL_ETOPO1_Ice_c_geotiff.tif /storage/mapserver-datasets/earth/etopo1/ETOPO1_Ice_c_geotiff.tif \
    gdaladdo -r cubic /storage/mapserver-datasets/earth/etopo1/ETOPO1_Ice_c_geotiff.tif 2 4 8 16 ;\
    \
    # Create Config Files \
    \
    \
    sh -c "$(/bin/echo -e "cat >> /etc/apache2/sites-available/000-default.conf <<EOF\
\nScriptAlias /cgi-bin/ /usr/lib/cgi-bin/\
\n<Directory \"/usr/lib/cgi-bin/\">\
\n        AllowOverride All\
\n        Options +ExecCGI -MultiViews +FollowSymLinks\
\n        AddHandler fcgid-script .fcgi\
\n        Require all granted\
\n</Directory>\
\nEOF\n")" ;\
    \
    \
    sh -c "$(/bin/echo -e "cat >> /storage/mapserver-datasets/epsg <<EOF\
\nScriptAlias /cgi-bin/ /usr/lib/cgi-bin/\
\n# custom rotated and scaled HEALPix, magic number is sqrt(2) * 2/pi\
\n<900914> +proj=healpix +lon_0=0 +x_0=2.5 +y_0=2.5 +a=0.900316316157106 +rot_xy=45 +no_defs <>\
\n# standard HEALPix on unit sphere\
\n<900915> +proj=healpix +a=1 +b=1 <>\
\nEOF\n")" ;\
    \
    \
    sh -c "$(/bin/echo -e "cat > /storage/mapserver-datasets/meta.map <<EOF\
\nMAP\
\n  NAME \"CosmoScout VR Maps\"\
\n  STATUS ON\
\n  EXTENT -180 -90 180 90\
\n  SIZE 800 400\
\n\
\n  # This tells the MapSever to look for PROJ init files next to this map file.\
\n  # This way we can use our custom epsg codes.\
\n  CONFIG \"PROJ_LIB\" \".\"\
\n\
\n  PROJECTION\
\n    \"init=epsg:4326\"\
\n  END\
\n\
\n  # This format will be requested by CosmoScout VR for elevation data.\
\n  OUTPUTFORMAT\
\n    NAME \"tiffGray\"\
\n    DRIVER \"GDAL/GTiff\"\
\n    IMAGEMODE FLOAT32\
\n    EXTENSION \"tiff\"\
\n    FORMATOPTION \"COMPRESS=LZW\"\
\n  END\
\n\
\n  # This format will be requested by CosmoScout VR for monochrome imagery data.\
\n  OUTPUTFORMAT\
\n    NAME \"pngGray\"\
\n    DRIVER \"GDAL/PNG\"\
\n    IMAGEMODE BYTE\
\n    EXTENSION \"png\"\
\n  END\
\n\
\n  # This format will be requested by CosmoScout VR for color imagery data.\
\n  OUTPUTFORMAT\
\n    NAME \"pngRGB\"\
\n    DRIVER \"GD/PNG\"\
\n    IMAGEMODE RGB\
\n    EXTENSION \"png\"\
\n  END\
\n\
\n  WEB\
\n    METADATA\
\n      WMS_TITLE           \"CosmoScout-VR-WMS-Server\"\
\n      WMS_ONLINERESOURCE  \"localhost/cgi-bin/mapserv?\"\
\n      WMS_ENABLE_REQUEST  \"*\"\
\n      WMS_SRS             \"EPSG:4326 EPSG:900914 EPSG:900915\"\
\n    END\
\n  END\
\n\
\n  INCLUDE \"earth/bluemarble/bluemarble.map\"\
\n  INCLUDE \"earth/naturalearth/naturalearth.map\"\
\n  INCLUDE \"earth/etopo1/etopo1.map\"\
\nEND\
\nEOF\n")" ;\
    \
    \
    sh -c "$(/bin/echo -e "cat > /storage/mapserver-datasets/earth/bluemarble/bluemarble.map <<EOF\
\nLAYER\
\n  NAME \"earth.bluemarble.rgb\"\
\n  STATUS ON\
\n  TYPE RASTER\
\n  DATA \"earth/bluemarble/bluemarble.jpg\"\
\n\
\n  # Decreasing the oversampling factor will increase performance but reduce quality.\
\n  PROCESSING \"OVERSAMPLE_RATIO=10\"\
\n  PROCESSING \"RESAMPLE=BILINEAR\"\
\n\
\n  # The JPEG file obviously does not contain any projection information.\
\n  # Therefore we have to give the extent and projection here.\
\n  EXTENT -180 -90 180 90\
\n\
\n  PROJECTION\
\n    \"init=epsg:4326\"\
\n  END\
\n\
\n  METADATA\
\n    WMS_TITLE \"earth.bluemarble.rgb\"\
\n  END\
\nEND\
\nEOF\n")" ;\
    \
    \
    sh -c "$(/bin/echo -e "cat > /storage/mapserver-datasets/earth/naturalearth/naturalearth.map <<EOF\
\nLAYER\
\n  NAME \"earth.naturalearth.rgb\"\
\n  STATUS ON\
\n  TYPE RASTER\
\n  DATA \"earth/naturalearth/NE1_HR_LC_SR_W_DR.tif\"\
\n\
\n  # Decreasing the oversampling factor will increase performance but reduce quality.\
\n  PROCESSING \"OVERSAMPLE_RATIO=10\"\
\n  PROCESSING \"RESAMPLE=BILINEAR\"\
\n\
\n  # The GeoTiff is fully geo-referenced, so we can just use AUTO projection here.\
\n  PROJECTION\
\n    AUTO\
\n  END\
\n\
\n  METADATA\
\n    WMS_TITLE \"earth.naturalearth.rgb\"\
\n  END\
\nEND\
\nEOF\n")" ;\
    \
    \
    sh -c "$(/bin/echo -e "cat > /storage/mapserver-datasets/earth/etopo1/etopo1.map <<EOF\
\nLAYER\
\n  NAME \"earth.etopo1.dem\"\
\n  STATUS ON\
\n  TYPE RASTER\
\n  DATA \"earth/etopo1/ETOPO1_Ice_c_geotiff.tif\"\
\n\
\n  # Decreasing the oversampling factor will increase performance but reduce quality.\
\n  PROCESSING \"OVERSAMPLE_RATIO=10\"\
\n  PROCESSING \"RESAMPLE=BILINEAR\"\
\n\
\n  # The ETOPO1 GeoTiff contains extent information but no projection...\
\n  PROJECTION\
\n    \"init=epsg:4326\"\
\n  END\
\n\
\n  METADATA\
\n    WMS_TITLE \"earth.etopo1.dem\"\
\n  END\
\nEND\
\nEOF\n")" ;\
    \
    \
    rm -rf /tmp/* \
    chown -R www-data: /storage

EXPOSE 80

WORKDIR /storage/mapserver-datasets

CMD ["apachectl", "-D", "FOREGROUND"]