import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/gp_plan_service.dart';

// แพ็กเกจตามโปสเตอร์ JDC
const plan1 = {'gp_rate': 0.15, 'base_delivery_fee': 10, 'base_distance_km': 5, 'per_km_charge': 3};
const plan2 = {'gp_rate': 0.20, 'base_delivery_fee': 5, 'base_distance_km': 7, 'per_km_charge': 2};
const plan3 = {'gp_rate': 0.25, 'base_delivery_fee': 0, 'base_distance_km': 10, 'per_km_charge': 1};

void main() {
  group('ตัวอย่างคำนวณแพ็กเกจ GP (หน้าเลือกแพ็กเกจ)', () {
    test('ค่าส่งภายในระยะที่รวมไว้ = ค่าเริ่มต้น', () {
      expect(GpPlanService.deliveryFeeFor(plan1, 4), 10);
      expect(GpPlanService.deliveryFeeFor(plan2, 7), 5);
      expect(GpPlanService.deliveryFeeFor(plan3, 10), 0);
    });

    test('เกินระยะคิดเพิ่มต่อกิโลเมตร (ลูกค้าห่าง 8 กม.)', () {
      expect(GpPlanService.deliveryFeeFor(plan1, 8), 19); // 10 + 3×3
      expect(GpPlanService.deliveryFeeFor(plan2, 8), 7); // 5 + 1×2
      expect(GpPlanService.deliveryFeeFor(plan3, 8), 0);
    });

    test('ร้านได้รับหลังหัก GP จากยอด 100 บาท', () {
      expect(GpPlanService.merchantReceivesFor(plan1, 100), 85);
      expect(GpPlanService.merchantReceivesFor(plan2, 100), 80);
      expect(GpPlanService.merchantReceivesFor(plan3, 100), 75);
    });

    test('ค่าติดลบ/ว่างไม่ทำให้คำนวณพัง', () {
      expect(GpPlanService.deliveryFeeFor(plan1, -5), 10);
      expect(GpPlanService.merchantReceivesFor(plan1, -20), 0);
      expect(GpPlanService.deliveryFeeFor(const {}, 9), 0);
      expect(GpPlanService.merchantReceivesFor(const {}, 100), 100);
    });
  });
}
