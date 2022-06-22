import osascript

def volume_up(amount):

    current_volume = get_current_volume()
    # print(current_volume)
    target_volume = str(current_volume + amount)
    print(target_volume)
    osascript.osascript("set volume output volume {}".format(target_volume))

def volume_down(amount):

    current_volume = get_current_volume()
    target_volume = str(current_volume - amount)
    print(target_volume)
    osascript.osascript("set volume output volume {}".format(target_volume))

def get_current_volume():
    result = osascript.osascript('get volume settings')
    # print(result)
    # print(type(result))
    volInfo = result[1].split(',')
    outputVol = volInfo[0].replace('output volume:', '')
    outputVol = int(outputVol)
    # print(outputVol)

    return outputVol
