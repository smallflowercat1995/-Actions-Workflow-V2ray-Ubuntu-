
#!/usr/bin/env bash
# 当前路径
PWD=`pwd`

cd -- ${PWD}

# 创建用户添加密码
createUserNamePassword(){

    # 判断用户名
    if [[ -z "$USER_NAME" ]]; then
      echo "Please set 'USER_NAME' for linux"
      exit 2
    fi

    sudo useradd -m $USER_NAME
    sudo adduser $USER_NAME sudo


    # 判断用户密码环境变量
    if [[ -z "$USER_PW" ]]; then
      echo "Please set 'USER_PW' for linux"
      exit 3
    fi

    echo "$USER_NAME:$USER_PW" | sudo chpasswd
    sudo sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd
    echo "Update linux user password !"
    echo -e "$USER_PW\n$USER_PW" | sudo passwd "$USER_NAME"

    # 判断用户hostname
    if [[ -z "$HOST_NAME" ]]; then
      echo "Please set 'HOST_NAME' for linux"
      exit 4
    fi

    sudo hostname $HOST_NAME
    
    unset USER_NAME USER_PW HOST_NAME
}

# 获取配置启动Ngrok
getStartNgrok(){
    # 判断 Ngrok 环境变量
    if [[ -z "$NGROK_AUTH_TOKEN" ]]; then
      echo "Please set 'NGROK_AUTH_TOKEN'"
      exit 5
    fi

    # Ngrok 下载链接
    URI_DOWNLOAD=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz

    # 文件名
    FILE_NAME=ngrok-linux-amd64.tgz

    # 下载
    curl -L -H "Connection: keep-alive" -k ${URI_DOWNLOAD} -o ${FILE_NAME} -O

    # 解压
    tar xvf ${FILE_NAME} ; chmod -v +x ngrok

    # 删除
    rm -fv ${FILE_NAME}

    # 配置文件生成
    echo -e "tunnels:\n    ssh:\n        proto: tcp\n        addr: 22\n    trojan:\n        proto: tcp\n        addr: 1234\n    v2ray:\n        proto: tcp\n        addr: 12345\nversion: '2'\n" > ngrok.yml

    # 启动 ngrok
    ./ngrok start --all --authtoken "$NGROK_AUTH_TOKEN" --config ngrok.yml --log ngrok.log &

    # 等待
    sleep 10

    HAS_ERRORS=$(grep "command failed" < ngrok.log)

    if [[ -z "$HAS_ERRORS" ]]; then
      echo ""
      echo "=========================================="
      echo -e "To connect: \n$(grep -o -E "name=(.+)" < ngrok.log | sed 's; ;\n;g' | grep -v addr)"
      echo "=========================================="
    else
      echo "$HAS_ERRORS"
      exit 6
    fi

    # 解除环境变量
    unset  HAS_ERRORS NGROK_AUTH_TOKEN URI_DOWNLOAD FILE_NAME
}

# 获取配置启动Trojan
getStartV2ray(){
    # 获取下载路径
    # https://github.com/v2fly/v2ray-core/releases/download/v5.1.0/v2ray-linux-64.zip
    DOWNLOAD=`curl -L 'https://github.com/v2fly/v2ray-core/releases' | sed 's;";\n;g;s;tag;download;g' | grep '/download/' | head -n 1`

    # 打印链接
    URI_DOWNLOAD="https://github.com${DOWNLOAD}/v2ray-linux-64.zip"
    echo ${URI_DOWNLOAD}

    # 文件名
    FILE_NAME=v2ray.zip

    # 下载
    curl -L -H "Connection: keep-alive" -k ${URI_DOWNLOAD} -o ${FILE_NAME} -O

    # 解压
    unzip -o ${FILE_NAME} -d $(echo $FILE_NAME | sed 's;.zip;;g') ; cd $(echo $FILE_NAME | sed 's;.zip;;g')

    # 生成配置文件
    cat << EOF >> config.json
    {
      "log": {
        "access": "access.log",
        "error": "error.log",
        "loglevel": "info"
      },
      "inbounds": [
        {
          "port": 1234,
          "protocol": "vmess",
          "settings": {
            "udp": false,
            "clients": [
              {
                "id": "ba0ee1fc-6fe1-4a52-980a-26a3ad651630",
                "alterId": 0,
                "email": "t@t.tt"
              }
            ],
            "allowTransparent": false
          },
          "streamSettings": {
            "network": "tcp"
          }
        }
      ],
      "outbounds": [
        {
          "protocol": "freedom"
        },
        {
          "tag": "block",
          "protocol": "blackhole",
          "settings": {}
        }
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": []
      }
    }
    EOF

    ./v2ray run -c config.json

    # 解除环境变量
    rm -rfv  ${FILE_NAME}

    # 解除环境变量
    unset DOWNLOAD URI_DOWNLOAD FILE_NAME
}

createUserNamePassword
getStartNgrok
getStartV2ray

unset PWD
