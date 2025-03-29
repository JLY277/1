import { util } from '@kit.ArkTS'
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, Filter, ListFileOptions, fileUri } from '@kit.CoreFileKit';
import { socket } from '@kit.NetworkKit';
import wifiManager from '@ohos.wifiManager';
import systemDateTime from '@ohos.systemDateTime';
import { preferences } from '@kit.ArkData';
import { UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';

let dataPreferences: preferences.Preferences | null = null;

class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage) {
    let options: preferences.Options = {
      name: 'myStore'
    };
    dataPreferences = preferences.getPreferencesSync(this.context, options);
  }
}


class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo;
}

// 创建一个TCPSocket连接，返回一个TCPSocket对象。
let tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
tcp.on('message', (value: SocketInfo) => {
  console.log("on message");
  let buffer = value.message;
  let dataView = new DataView(buffer);
  let str = "";
  for (let i = 0; i < dataView.byteLength; ++i) {
    str += String.fromCharCode(dataView.getUint8(i));
  }
  console.log("on connect received:" + str);
});
tcp.on('connect', () => {
  console.log("on connect");
});
tcp.on('close', () => {
  console.log("on close");
});

// 绑定本地IP地址和端口。
//本地IP的数值形式
let ipNum = wifiManager.getIpInfo().ipAddress
//本地IP的字符串形式
let localIp = (ipNum >>> 24) + '.' + (ipNum >> 16 & 0xFF) + '.' + (ipNum >> 8 & 0xFF) + '.' + (ipNum & 0xFF);

// 本地IP地址和端口
let ipAddress: socket.NetAddress = { address: localIp, port: 9990 };


tcp.bind(ipAddress, (err: BusinessError) => {
  if (err) {
    console.log('bind fail');
    return;
  }
  console.log('bind success');

  // 连接到指定的IP地址和端口。
  ipAddress.address = "192.168.xxx.xxx";
  ipAddress.port = 5678;

  let tcpConnect: socket.TCPConnectOptions = {} as socket.TCPConnectOptions;
  tcpConnect.address = ipAddress;
  tcpConnect.timeout = 6000;

  tcp.connect(tcpConnect).then(() => {
    console.log('connect success');
    let tcpSendOptions: socket.TCPSendOptions = {
      data: 'Hello, server!'
    }
    tcp.send(tcpSendOptions).then(() => {
      console.log('send success');
    }).catch((err: BusinessError) => {
      console.log('send fail');
    });
  }).catch((err: BusinessError) => {
    console.log('connect fail');
  });
});

// 连接使用完毕后，主动关闭。取消相关事件的订阅。
setTimeout(() => {
  tcp.close().then(() => {
    console.log('close success');
  }).catch((err: BusinessError) => {
    console.log('close fail');
  });
  tcp.off('message');
  tcp.off('connect');
  tcp.off('close');
}, 30 * 1000);


@Builder
export function SettingBuilder(name: string,

) {
  SettingTmp();
}

@Component
export struct SettingTmp {
  @Consume('pageInfos') pageInfos: NavPathStack;
  @Consume('lightState') lightState: boolean;
  @State private IPInput: string = ''; // 用来存储用户输入的IP
  @State private PortInput: string = ''; //用来存储用户输入的端口

  private onLightStateChanged(newValue: boolean) {
    const valueToSend = newValue ? '1' : '0';
    const tcpSendOptions: socket.TCPSendOptions = {
      data: valueToSend
    };
    tcp.send(tcpSendOptions).then(() => {
      console.log('Light state sent successfully: ' + valueToSend);
    }).catch((err: BusinessError) => {
      console.log('Failed to send light state: ' + err.message);
    });
  }

  conserve() {
    if (dataPreferences) { // Ensure dataPreferences is not null
      dataPreferences.putSync('IP', this.IPInput);
      dataPreferences.putSync('Port', this.PortInput);
    } else {
      console.log('dataPreferences is null. Cannot save data.');
    }
  }

  //ArrayBuffer转utf8字符串
  private buf2String(buf: ArrayBuffer) {
    let msgArray = new Uint8Array(buf);
    let textDecoder = util.TextDecoder.create("utf-8");
    return textDecoder.decodeWithStream(msgArray)
  }

  build() {
    NavDestination() {
      Column() {
        List() {
          ListItem() {
            Row() {
              Text('IP')
                .textAlign(TextAlign.Start)
              TextArea({ text: $$this.IPInput, placeholder: "Enter IP here..." })
                .onChange((value: string, previewText?: PreviewText) => this.IPInput = value)
                .width('80%')
                .textAlign(TextAlign.End)

            }

          }.width('100%')
          .height('80%')

          ListItem() {
            Row() {
              Text('Port')
                .textAlign(TextAlign.Start)
              TextArea({ text: $$this.PortInput, placeholder: "Enter Port here..." })
                .onChange((value: string, previewText?: PreviewText) => this.PortInput = value)
                .width('80%')
                .textAlign(TextAlign.End)
            }
          }

        }.width('100%')
        .height('80%')
        .alignListItem(ListItemAlign.Center)

        Row() {
          Button('connect')
            .onClick(() => {
              this.conserve(); // 确保 sendMessage 方法被正确调用
            })
            .width('20%')
        }
      }.width('90%')
    }.title("net setting")
    .onBackPressed(() => {
      const popDestinationInfo = this.pageInfos.pop() // 弹出路由栈栈顶元素
      console.log('pop' + '返回值' + JSON.stringify(popDestinationInfo))
      return true
    })
  }
}