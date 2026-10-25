from pathlib import Path
p=Path('docs/mechanical/fusion-controller/05_sensor.py');s=p.read_text()
s=s.replace('13 if sg>0 else -23','18 if sg>0 else -28').replace('23 if sg>0 else -13','28 if sg>0 else -18').replace('16.3 if sg>0 else -23.1','21.3 if sg>0 else -28.1')
s=s.replace('(80,-28,46),(83,28,84)','(80,-33,46),(83,33,84)').replace('23 if sg>0 else -28','28 if sg>0 else -33').replace('28 if sg>0 else -23','33 if sg>0 else -28').replace('22.9 if sg>0 else -28.1','27.9 if sg>0 else -33.1')
p.write_text(s)
p=Path('docs/mechanical/fusion-controller/07_hardware.py');s=p.read_text().replace('sg*28.5,sg*16.5','sg*33.5,sg*21.5').replace('28 if sg>0 else -28.5','33 if sg>0 else -33.5');p.write_text(s)
