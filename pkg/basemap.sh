#!/usr/bin/env bash

set -e
set -x

## SETTINGS

# Remove features smaller than X square meters from different detail levels

AREA_CRUDE=1000000
AREA_LOW=500000
AREA_MEDIUM=100000
AREA_HIGH=10000

# Simplify polygons to X degrees

SIMPL_CRUDE=0.05
SIMPL_LOW=0.02
SIMPL_MEDIUM=0.005
SIMPL_HIGH=0.0002

## END OF SETTINGS

#wget https://osmdata.openstreetmap.de/download/land-polygons-complete-4326.zip
unzip land-polygons-complete-4326.zip

qgis_process run native:fieldcalculator --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=land-polygons-complete-4326/land_polygons.shp --FIELD_NAME=area --FIELD_TYPE=0 --FIELD_LENGTH=0 --FIELD_PRECISION=0 --FORMULA=' $area ' --OUTPUT=full_witharea.shp

# Remove small polygons (crude)
qgis_process run native:extractbyattribute --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=full_witharea.shp --FIELD=area --OPERATOR=2 --VALUE=${AREA_CRUDE} --OUTPUT=clean_crude.shp

# Remove small polygons (low)
qgis_process run native:extractbyattribute --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=full_witharea.shp --FIELD=area --OPERATOR=2 --VALUE=${AREA_LOW} --OUTPUT=clean_low.shp

# Remove small polygons (medium)
qgis_process run native:extractbyattribute --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=full_witharea.shp --FIELD=area --OPERATOR=2 --VALUE=${AREA_MEDIUM} --OUTPUT=clean_medium.shp

# Remove small polygons (high)
qgis_process run native:extractbyattribute --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=full_witharea.shp --FIELD=area --OPERATOR=2 --VALUE=${AREA_HIGH} --OUTPUT=clean_high.shp

# Clean up the temporary data
rm -f full_witharea.*

# Simplify geometries - crude
qgis_process run native:simplifygeometries --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=clean_crude.shp --METHOD=0 --TOLERANCE=${SIMPL_CRUDE} --OUTPUT=simplified_crude.shp

# Simplify geometries - low
qgis_process run native:simplifygeometries --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=clean_low.shp --METHOD=0 --TOLERANCE=${SIMPL_LOW} --OUTPUT=simplified_low.shp

# Simplify geometries - medium
qgis_process run native:simplifygeometries --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=clean_medium.shp --METHOD=0 --TOLERANCE=${SIMPL_MEDIUM} --OUTPUT=simplified_medium.shp

# Simplify geometries - high
qgis_process run native:simplifygeometries --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=clean_high.shp --METHOD=0 --TOLERANCE=${SIMPL_HIGH} --OUTPUT=simplified_high.shp

# Clean up the temporary data
rm -f clean_*

# Create grids
# 10x10 degrees
qgis_process run native:creategrid --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --TYPE=2 --EXTENT='-180.000000000,180.000000000,-90.000000000,90.000000000 [EPSG:4326]' --HSPACING=10 --VSPACING=10 --HOVERLAY=0 --VOVERLAY=0 --CRS='EPSG:4326' --OUTPUT=grid10x10.shp
# 1x1 degrees
qgis_process run native:creategrid --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --TYPE=2 --EXTENT='-180.000000000,180.000000000,-90.000000000,90.000000000 [EPSG:4326]' --HSPACING=1 --VSPACING=1 --HOVERLAY=0 --VOVERLAY=0 --CRS='EPSG:4326' --OUTPUT=grid1x1.shp
# 0.25x0.25 degrees
qgis_process run native:creategrid --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --TYPE=2 --EXTENT='-180.000000000,180.000000000,-90.000000000,90.000000000 [EPSG:4326]' --HSPACING=1 --VSPACING=1 --HOVERLAY=0 --VOVERLAY=0 --CRS='EPSG:4326' --OUTPUT=grid025x025.shp
# Fill X/Y fields with the lon/lat of the grid cell

cat grid_fields.json | sed 's/<INPUT>/grid10x10.shp/g' | sed 's/<OUTPUT>/grid_10x10.shp/g' | qgis_process run native:refactorfields -
cat grid_fields.json | sed 's/<INPUT>/grid1x1.shp/g' | sed 's/<OUTPUT>/grid_1x1.shp/g' | qgis_process run native:refactorfields -
cat 025x025_fields.json | qgis_process run native:refactorfields -

# Tile the shapefiles
qgis_process run native:intersection --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=grid_10x10.shp --OVERLAY=simplified_crude.shp --OVERLAY_FIELDS_PREFIX= --OUTPUT=tmp_basemap_crude_10x10.shp
qgis_process run native:intersection --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=grid_1x1.shp --OVERLAY=simplified_low.shp --OVERLAY_FIELDS_PREFIX= --OUTPUT=tmp_basemap_low.shp
qgis_process run native:intersection --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=grid_1x1.shp --OVERLAY=simplified_medium.shp --OVERLAY_FIELDS_PREFIX= --OUTPUT=tmp_basemap_medium.shp
qgis_process run native:intersection --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=grid_1x1.shp --OVERLAY=simplified_high.shp --OVERLAY_FIELDS_PREFIX= --OUTPUT=tmp_basemap_high.shp
# Full, a bit different, we start with the original OSM polygons
qgis_process run native:intersection --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=grid_1x1.shp --OVERLAY=land-polygons-complete-4326/land_polygons.shp --OVERLAY_FIELDS_PREFIX= --OUTPUT=tmp_basemap_full.shp
#qgis_process run native:intersection --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT=grid_025x025.shp --OVERLAY=land-polygons-complete-4326/land_polygons.shp --OVERLAY_FIELDS_PREFIX= --OUTPUT=tmp_basemap_full_025x025.shp

cat final_fields.json | sed 's/<INPUT>/tmp_basemap_crude_10x10.shp/g' | sed 's/<OUTPUT>/basemap_crude_10x10.shp/g' | qgis_process run native:refactorfields -
cat final_fields.json | sed 's/<INPUT>/tmp_basemap_low.shp/g' | sed 's/<OUTPUT>/basemap_low.shp/g' | qgis_process run native:refactorfields -
cat final_fields.json | sed 's/<INPUT>/tmp_basemap_medium.shp/g' | sed 's/<OUTPUT>/basemap_medium.shp/g' | qgis_process run native:refactorfields -
cat final_fields.json | sed 's/<INPUT>/tmp_basemap_high.shp/g' | sed 's/<OUTPUT>/basemap_high.shp/g' | qgis_process run native:refactorfields -
cat final_fields.json | sed 's/<INPUT>/tmp_basemap_full.shp/g' | sed 's/<OUTPUT>/basemap_full.shp/g' | qgis_process run native:refactorfields -
#cat final_fields.json | sed 's/<INPUT>/tmp_basemap_full_025x025.shp/g' | sed 's/<OUTPUT>/basemap_full_025x025.shp/g' | qgis_process run native:refactorfields -

# Remove temporary data
rm -f simplified_*
rm -f tmp_basemap_*
rm -f grid*x*.*

# Remove source data
rm -rf land-polygons-complete-4326
rm -f land-polygons-complete-4326.zip

# Create the archives
tar c basemap_crude_10x10.* | pxz -9 > basemap_crude.tar.xz
tar c basemap_low.* | pxz -9 > basemap_low.tar.xz
tar c basemap_medium.* | pxz -9 > basemap_medium.tar.xz
tar c basemap_high.* | pxz -9 > basemap_high.tar.xz
tar c basemap_full.* | pxz -9 > basemap_full.tar.xz

rm -f *.shp *.dbf *.shx *prj *.cpg
