import 'dart:io';
import 'package:jupiter/storage.dart';
import 'package:vibration/vibration.dart';

class AppHaptics{
  static void initialise(){
    Future.delayed(Duration.zero, ()async{
      final value = DataCache.getNeedsHaptics() ?? true;
      if(value){
        await setVibrationState(true);
      }
    });
  }

  static Future<bool> _canAppVibrate()async{
    if(!Platform.isAndroid){
      return false;
    }
    final canVibrate = await Vibration.hasVibrator();
    final settingsVibrate = DataCache.getNeedsHaptics() ?? true;
    if(!canVibrate || !settingsVibrate){
      return false;
    }
    return true;
  }

  static Future<void> setVibrationState(bool canVibrate)async{
    await DataCache.setNeedsHaptics(canVibrate ? 1 : 0);
  }

  static void lightImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await Vibration.vibrate(pattern: [0, 10], intensities: [1]);
    });
  }

  static void mediumImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await Vibration.vibrate(duration: 16, pattern: [0, 16], intensities: [15]);
    });
  }

  static void textEditingImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await Vibration.vibrate(duration: 1, pattern: [0, 1], intensities: [1]);
    });
  }

  static void attentionImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await Vibration.vibrate(duration: 195, pattern: [0, 35, 125, 35], intensities: [20, 10]);
    });
  }

  static void attentionLightImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await Vibration.vibrate(duration: 130, pattern: [0, 15, 100, 15], intensities: [10, 5]);
    });
  }
}