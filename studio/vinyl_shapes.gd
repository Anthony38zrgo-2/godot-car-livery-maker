extends RefCounted

const LABELS := ["Rectangulo", "Rectangulo redondeado", "Circulo", "Triangulo", "Trapecio", "Franja afinada", "Franja doble", "Franja triple", "Chevron", "Rayo", "Curva deportiva", "Barrido deportivo", "Bandera a cuadros", "Numero"]

static func svg(layer: Dictionary) -> String:
 var fill: String = layer.get("color", "ffffffff")
 var stroke: String = layer.get("border_color", "000000ff")
 var width := float(layer.get("border", 0.02)) * 128.0
 var style := ' fill="#%s" fill-opacity="%s" stroke="#%s" stroke-opacity="%s" stroke-width="%s" stroke-linejoin="round"' % [fill.substr(0,6), Color.from_string(fill, Color.WHITE).a, stroke.substr(0,6), Color.from_string(stroke, Color.BLACK).a, width]
 var body := ""
 var shape := int(layer.get("shape", 0))
 var curve := clampf(float(layer.get("curve", 0.5)),0.0,1.0)
 match shape:
  0: body = '<rect x="8" y="8" width="112" height="112"%s/>' % style
  1: body = '<rect x="8" y="8" width="112" height="112" rx="20"%s/>' % style
  2: body = '<ellipse cx="64" cy="64" rx="56" ry="56"%s/>' % style
  3: body = '<polygon points="64,8 120,120 8,120"%s/>' % style
  4: body = '<polygon points="30,8 98,8 120,120 8,120"%s/>' % style
  5: body = '<polygon points="8,42 120,8 120,120 8,86"%s/>' % style
  6, 7:
   var count := 2 if shape == 6 else 3
   for i in count:
    body += '<rect x="8" y="%s" width="112" height="%s"%s/>' % [8 + i * (112.0/count), 112.0/count-10, style]
  8: body = '<polygon points="8,8 70,8 120,64 70,120 8,120 58,64"%s/>' % style
  9: body = '<polygon points="68,8 20,72 60,72 40,120 112,48 76,48 100,8"%s/>' % style
  10: body = '<path d="M8 110 C30 %s 76 %s 120 8 L120 42 C70 %s 48 %s 8 120 Z"%s/>' % [lerpf(90,12,curve),lerpf(48,112,curve),lerpf(60,126,curve),lerpf(100,52,curve),style]
  11: body = '<path d="M8 120 Q45 %s 120 8 L120 62 Q54 %s 8 120 Z"%s/>' % [lerpf(95,15,curve),lerpf(105,45,curve),style]
  12:
   for y in 4:
    for x in 4:
     if (x+y)%2 == 0: body += '<rect x="%s" y="%s" width="28" height="28"%s/>' % [8+x*28,8+y*28,style]
  13:
   var digits := str(clampi(int(layer.get("number", 1)), 0, 99))
   var segments := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]
   var rects := {"a":Rect2(8,4,36,9),"b":Rect2(40,12,9,40),"c":Rect2(40,62,9,40),"d":Rect2(8,102,36,9),"e":Rect2(3,62,9,40),"f":Rect2(3,12,9,40),"g":Rect2(8,53,36,9)}
   for i in digits.length():
    body += '<g transform="translate(%s 8)">' % (38 if digits.length()==1 else 10+i*56)
    for segment in segments[int(digits[i])]:
     var r: Rect2 = rects[segment]
     body += '<rect x="%s" y="%s" width="%s" height="%s"%s/>' % [r.position.x,r.position.y,r.size.x,r.size.y,style]
    body += '</g>'
 return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-8 -8 144 144">%s</svg>' % body

static func image(layer: Dictionary) -> Image:
 var result := Image.new()
 var error := result.load_svg_from_string(svg(layer), 2.0)
 if error != OK: push_error("No se pudo generar el vinilo")
 return result
