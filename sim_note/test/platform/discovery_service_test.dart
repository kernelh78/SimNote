import 'package:flutter_test/flutter_test.dart';
import 'package:sim_note/sync/discovery_service.dart';

void main() {
  group('DiscoveryService.subnetBroadcast', () {
    test('192.168.x.x → 마지막 옥텟을 255로 변환', () {
      expect(DiscoveryService.subnetBroadcast('192.168.0.5'),   equals('192.168.0.255'));
      expect(DiscoveryService.subnetBroadcast('192.168.1.100'), equals('192.168.1.255'));
      expect(DiscoveryService.subnetBroadcast('192.168.10.1'),  equals('192.168.10.255'));
    });

    test('10.x.x.x 범위 정상 처리', () {
      expect(DiscoveryService.subnetBroadcast('10.0.0.1'),   equals('10.0.0.255'));
      expect(DiscoveryService.subnetBroadcast('10.10.20.5'), equals('10.10.20.255'));
    });

    test('172.16.x.x 범위 정상 처리', () {
      expect(DiscoveryService.subnetBroadcast('172.16.0.1'),  equals('172.16.0.255'));
      expect(DiscoveryService.subnetBroadcast('172.31.5.10'), equals('172.31.5.255'));
    });

    test('잘못된 형식 → 255.255.255.255 반환', () {
      expect(DiscoveryService.subnetBroadcast('invalid'), equals('255.255.255.255'));
      expect(DiscoveryService.subnetBroadcast(''),        equals('255.255.255.255'));
    });
  });

  group('DiscoveryService.isVirtualInterface', () {
    test('VPN 인터페이스 감지', () {
      expect(DiscoveryService.isVirtualInterface('tun0'),    isTrue);
      expect(DiscoveryService.isVirtualInterface('tap0'),    isTrue);
      expect(DiscoveryService.isVirtualInterface('vpn0'),    isTrue);
      expect(DiscoveryService.isVirtualInterface('utun3'),   isTrue);
    });

    test('Docker/VM 인터페이스 감지', () {
      expect(DiscoveryService.isVirtualInterface('docker0'),  isTrue);
      expect(DiscoveryService.isVirtualInterface('br-abc'),   isTrue);
      expect(DiscoveryService.isVirtualInterface('vmnet8'),   isTrue);
      expect(DiscoveryService.isVirtualInterface('bridge0'),  isTrue);
    });

    test('실제 물리 인터페이스는 가상 아님', () {
      expect(DiscoveryService.isVirtualInterface('eth0'),   isFalse);
      expect(DiscoveryService.isVirtualInterface('wlan0'),  isFalse);
      expect(DiscoveryService.isVirtualInterface('en0'),    isFalse);
      expect(DiscoveryService.isVirtualInterface('en1'),    isFalse);
      expect(DiscoveryService.isVirtualInterface('Wi-Fi'),  isFalse);
    });
  });

  group('DiscoveryService.isCommonPrivate', () {
    test('192.168.x.x — 사설 IP', () {
      expect(DiscoveryService.isCommonPrivate('192.168.0.1'),   isTrue);
      expect(DiscoveryService.isCommonPrivate('192.168.1.100'), isTrue);
      expect(DiscoveryService.isCommonPrivate('192.168.255.1'), isTrue);
    });

    test('10.x.x.x — 사설 IP', () {
      expect(DiscoveryService.isCommonPrivate('10.0.0.1'),    isTrue);
      expect(DiscoveryService.isCommonPrivate('10.255.255.1'), isTrue);
    });

    test('172.16~31.x.x — 사설 IP', () {
      expect(DiscoveryService.isCommonPrivate('172.16.0.1'),  isTrue);
      expect(DiscoveryService.isCommonPrivate('172.20.5.10'), isTrue);
      expect(DiscoveryService.isCommonPrivate('172.31.0.1'),  isTrue);
    });

    test('172.15 / 172.32 — 사설 IP 범위 밖', () {
      expect(DiscoveryService.isCommonPrivate('172.15.0.1'), isFalse);
      expect(DiscoveryService.isCommonPrivate('172.32.0.1'), isFalse);
    });

    test('공인 IP — 사설 아님', () {
      expect(DiscoveryService.isCommonPrivate('8.8.8.8'),      isFalse);
      expect(DiscoveryService.isCommonPrivate('1.1.1.1'),      isFalse);
      expect(DiscoveryService.isCommonPrivate('203.0.113.1'),  isFalse);
    });

    test('루프백 — 사설 아님', () {
      expect(DiscoveryService.isCommonPrivate('127.0.0.1'), isFalse);
    });
  });
}
