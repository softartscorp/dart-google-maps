// Copyright (c) 2015, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of google_maps.src;

@JsName('google.maps.Data.GeometryCollection')
abstract class _DataGeometryCollection extends DataGeometry {
  _DataGeometryCollection.created(JsObject o) : super.created(o);
  _DataGeometryCollection(List<dynamic /*DataGeometry|LatLng*/ > elements)
      : this.created(JsObject(
            context['google']['maps']['Data']['GeometryCollection']
                as JsFunction,
            [
              (JsListCodec<dynamic /*DataGeometry|LatLng*/ >(ChainedCodec()
                    ..add(JsInterfaceCodec<DataGeometry>(
                        (o) => DataGeometry.created(o),
                        (o) =>
                            o != null &&
                            o.instanceof(context['google']['maps']['Data']
                                ['Geometry'] as JsFunction)))
                    ..add(JsInterfaceCodec<LatLng>(
                        (o) => LatLng.created(o),
                        (o) =>
                            o != null &&
                            o.instanceof(context['google']['maps']['LatLng']
                                as JsFunction)))))
                  .encode(elements)
            ]));
  List<dynamic /*DataGeometryCollection|DataMultiPolygon|DataPolygon|DataLinearRing|DataMultiLineString|DataLineString|DataMultiPoint|DataPoint*/ > get array =>
      (JsListCodec<dynamic /*DataGeometryCollection|DataMultiPolygon|DataPolygon|DataLinearRing|DataMultiLineString|DataLineString|DataMultiPoint|DataPoint*/ >(ChainedCodec()
            ..add(JsInterfaceCodec<DataGeometryCollection>(
                (o) => DataGeometryCollection.created(o),
                (o) =>
                    o != null &&
                    o.instanceof(context['google']['maps']['Data']
                        ['GeometryCollection'] as JsFunction)))
            ..add(JsInterfaceCodec<DataMultiPolygon>(
                (o) => DataMultiPolygon.created(o),
                (o) =>
                    o != null &&
                    o.instanceof(context['google']['maps']['Data']['MultiPolygon'] as JsFunction)))
            ..add(JsInterfaceCodec<DataPolygon>((o) => DataPolygon.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['Polygon'] as JsFunction)))
            ..add(JsInterfaceCodec<DataLinearRing>((o) => DataLinearRing.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['LinearRing'] as JsFunction)))
            ..add(JsInterfaceCodec<DataMultiLineString>((o) => DataMultiLineString.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['MultiLineString'] as JsFunction)))
            ..add(JsInterfaceCodec<DataLineString>((o) => DataLineString.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['LineString'] as JsFunction)))
            ..add(JsInterfaceCodec<DataMultiPoint>((o) => DataMultiPoint.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['MultiPoint'] as JsFunction)))
            ..add(JsInterfaceCodec<DataPoint>((o) => DataPoint.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['Point'] as JsFunction)))))
          .decode(_getArray() as JsArray);
  _getArray();

  dynamic /*DataGeometryCollection|DataMultiPolygon|DataPolygon|DataLinearRing|DataMultiLineString|DataLineString|DataMultiPoint|DataPoint*/ getAt(num n) => (ChainedCodec()
        ..add(JsInterfaceCodec<DataGeometryCollection>(
            (o) => DataGeometryCollection.created(o),
            (o) =>
                o != null &&
                o.instanceof(context['google']['maps']['Data']
                    ['GeometryCollection'] as JsFunction)))
        ..add(JsInterfaceCodec<DataMultiPolygon>(
            (o) => DataMultiPolygon.created(o),
            (o) =>
                o != null &&
                o.instanceof(context['google']['maps']['Data']['MultiPolygon']
                    as JsFunction)))
        ..add(JsInterfaceCodec<DataPolygon>(
            (o) => DataPolygon.created(o),
            (o) =>
                o != null && o.instanceof(context['google']['maps']['Data']['Polygon'] as JsFunction)))
        ..add(JsInterfaceCodec<DataLinearRing>((o) => DataLinearRing.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['LinearRing'] as JsFunction)))
        ..add(JsInterfaceCodec<DataMultiLineString>((o) => DataMultiLineString.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['MultiLineString'] as JsFunction)))
        ..add(JsInterfaceCodec<DataLineString>((o) => DataLineString.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['LineString'] as JsFunction)))
        ..add(JsInterfaceCodec<DataMultiPoint>((o) => DataMultiPoint.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['MultiPoint'] as JsFunction)))
        ..add(JsInterfaceCodec<DataPoint>((o) => DataPoint.created(o), (o) => o != null && o.instanceof(context['google']['maps']['Data']['Point'] as JsFunction))))
      .decode(_getAt(n));
  _getAt(num n);

  num get length => _getLength();
  num _getLength();
  String get type => _getType();
  String _getType();
}
