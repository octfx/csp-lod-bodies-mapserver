# LOD Bodies Mapserver

A dockerized mapserver based on CosmoScouts LOD Bodies [documentation](https://github.com/cosmoscout/cosmoscout-vr/tree/develop/plugins/csp-lod-bodies).

Contains NASA's Blue Marble and the Natural Earth image datasets and ETOPO1 elevation data.  
The webserver is exposed on port 80.

Pull the image `docker pull octfx/lod-bodies-mapserver`

## Usage
Run the image:
```shell
docker run -it -d --name=lod-bodies-mapserver -p 0.0.0.0:8080:80 octfx/lod-bodies-mapserver
```

Add the following lines to `share/config/simple_desktop.json` and **remove** the `"Earth"` section from `"csp-simple-bodies"`.
```
"csp-lod-bodies": {
  "maxGPUTilesColor": 1024,
  "maxGPUTilesGray": 1024,
  "maxGPUTilesDEM": 1024,
  "mapCache": "/tmp/map-cache/",
  "bodies": {
    "Earth": {
      "activeImgDataset": "Blue Marble",
      "activeDemDataset": "ETOPO1",
      "imgDatasets": {
        "Blue Marble": {
          "copyright": "NASA",
          "url": "http://CONTAINER-IP:8080/cgi-bin/mapserv?map=/storage/mapserver-datasets/meta.map&service=wms",
          "format": "U8Vec3",
          "layers": "earth.bluemarble.rgb",
          "maxLevel": 6
        },
        "Natural Earth": {
          "copyright": "NASA",
          "url": "http://CONTAINER-IP:8080/cgi-bin/mapserv?map=/storage/mapserver-datasets/meta.map&service=wms",
          "format": "U8Vec3",
          "layers": "earth.naturalearth.rgb",
          "maxLevel": 6
        }
      },
      "demDatasets": {
        "ETOPO1": {
          "copyright": "NOAA",
          "url": "http://CONTAINER-IP:8080/cgi-bin/mapserv?map=/storage/mapserver-datasets/meta.map&service=wms",
          "format": "Float32",
          "layers": "earth.etopo1.dem",
          "maxLevel": 6
        }
      }
    }
  }
},
```