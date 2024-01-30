package vn.starposvietnam.bluetooth_printer;

import android.Manifest;
import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.Activity;
import android.app.Application;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothSocket;
import android.bluetooth.BluetoothStatusCodes;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanSettings;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;
import android.util.SparseArray;
import android.widget.Toast;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;

import vn.starposvietnam.bluetooth_printer.FlutterStarPOSPrinterPlugin.LogLevel;

import java.io.StringWriter;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;

import java.lang.reflect.Method;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

public class FlutterStarPOSPrinterPlugin implements
        FlutterPlugin,
        MethodCallHandler,
        RequestPermissionsResultListener,
        ActivityResultListener,
        ActivityAware {
    private static final String TAG = "[starPOS-Printer]";

    private LogLevel logLevel = LogLevel.DEBUG;

    private Context context;
    private MethodChannel methodChannel;
    private static final String NAMESPACE = "starpos_bluetooth_printer";

    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;

    private BluetoothSocket mBluetoothSocket;
    // private boolean mIsScanning = false;

    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    static final private String CCCD = "2902";

    private final Map<String, BluetoothDevice> mConnectedDevices = new ConcurrentHashMap<>();

    private final Map<String, BluetoothDevice> mBondingDevices = new ConcurrentHashMap<>();

    private final Map<Integer, OperationOnPermission> operationsOnPermission = new HashMap<>();
    private int lastEventId = 1452;

    private final int enableBluetoothRequestCode = 1879842617;

    private static final UUID PRINTER_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    public static final int PRINT_WIDTH_65 = 380;

    private interface OperationOnPermission {
        void op(boolean granted, String permission);
    }

    public FlutterStarPOSPrinterPlugin() {
    }

    // returns 128-bit representation
    public String uuid128(Object uuid) {
        if (!(uuid instanceof UUID) && !(uuid instanceof String)) {
            throw new IllegalArgumentException("input must be UUID or String");
        }

        String s = uuid.toString();

        if (s.length() == 4) {
            // 16-bit uuid
            return String.format("0000%s-0000-1000-8000-00805f9b34fb", s).toLowerCase();
        } else if (s.length() == 8) {
            // 32-bit uuid
            return String.format("%s-0000-1000-8000-00805f9b34fb", s).toLowerCase();
        } else {
            // 128-bit uuid
            return s.toLowerCase();
        }
    }

    // returns shortest representation
    public String uuidStr(Object uuid) {
        String s = uuid128(uuid);
        boolean starts = s.startsWith("0000");
        boolean ends = s.endsWith("-0000-1000-8000-00805f9b34fb");
        if (starts && ends) {
            // 16-bit
            return s.substring(4, 8);
        } else if (ends) {
            // 32-bit
            return s.substring(0, 8);
        } else {
            // 128-bit
            return s;
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        log(LogLevel.DEBUG, "onAttachedToEngine");

        pluginBinding = flutterPluginBinding;

        this.context = (Application) pluginBinding.getApplicationContext();

        methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), NAMESPACE + "/methods");
        methodChannel.setMethodCallHandler(this);

        IntentFilter filterAdapter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
        this.context.registerReceiver(mBluetoothAdapterStateReceiver, filterAdapter);

        IntentFilter filterBond = new IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED);
        this.context.registerReceiver(mBluetoothBondStateReceiver, filterBond);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        log(LogLevel.DEBUG, "onDetachedFromEngine");

        invokeMethodUIThread("OnDetachedFromEngine", new HashMap<>());

        pluginBinding = null;

        // stop scanning
        // if (mBluetoothAdapter != null && mIsScanning) {
        // BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
        // if (scanner != null) {
        // scanner.stopScan(getScanCallback());
        // mIsScanning = false;
        // }
        // }

        if (mBluetoothSocket != null) {
            try {
                OutputStream out = mBluetoothSocket.getOutputStream();
                out.close();
                mBluetoothSocket.close();
                mBluetoothSocket = null;
            } catch (IOException e) {
                e.printStackTrace();
            }

        }

        disconnectAllDevices("onDetachedFromEngine");

        context.unregisterReceiver(mBluetoothBondStateReceiver);
        context.unregisterReceiver(mBluetoothAdapterStateReceiver);
        context = null;

        methodChannel.setMethodCallHandler(null);
        methodChannel = null;

        mBluetoothAdapter = null;
        mBluetoothManager = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        log(LogLevel.DEBUG, "onAttachedToActivity");
        activityBinding = binding;
        activityBinding.addRequestPermissionsResultListener(this);
        activityBinding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        log(LogLevel.DEBUG, "onDetachedFromActivityForConfigChanges");
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        log(LogLevel.DEBUG, "onReattachedToActivityForConfigChanges");
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        log(LogLevel.DEBUG, "onDetachedFromActivity");
        activityBinding.removeRequestPermissionsResultListener(this);
        activityBinding = null;
    }

    ////////////////////////////////////////////////////////////
    // ███ ███ ███████ ████████ ██ ██ ██████ ██████
    // ████ ████ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ████ ██ █████ ██ ███████ ██ ██ ██ ██
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ███████ ██ ██ ██ ██████ ██████
    //
    // ██████ █████ ██ ██
    // ██ ██ ██ ██ ██
    // ██ ███████ ██ ██
    // ██ ██ ██ ██ ██
    // ██████ ██ ██ ███████ ███████

    @SuppressLint("MissingPermission")
    @Override
    @SuppressWarnings({ "deprecation", "unchecked" })
    // needed for compatability, type safety uses bluetooth_msgs.dart
    public void onMethodCall(@NonNull MethodCall call,
            @NonNull Result result) {
        try {
            log(LogLevel.DEBUG, "onMethodCall: " + call.method);

            // initialize adapter
            if (mBluetoothAdapter == null) {
                log(LogLevel.DEBUG, "initializing BluetoothAdapter");
                mBluetoothManager = (BluetoothManager) this.context.getSystemService(Context.BLUETOOTH_SERVICE);
                mBluetoothAdapter = mBluetoothManager != null ? mBluetoothManager.getAdapter() : null;
            }

            // check that we have an adapter, except for
            // the functions that do not need it
            if (mBluetoothAdapter == null &&
                    "flutterHotRestart".equals(call.method) == false &&
                    "connectedCount".equals(call.method) == false &&
                    "setLogLevel".equals(call.method) == false &&
                    "isSupported".equals(call.method) == false &&
                    "getAdapterName".equals(call.method) == false &&
                    "getAdapterState".equals(call.method) == false) {
                result.error("bluetoothUnavailable", "the device does not support bluetooth", null);
                return;
            }

            switch (call.method) {

                case "flutterHotRestart": {
                    // no adapter?
                    if (mBluetoothAdapter == null) {
                        result.success(0); // no work to do
                        break;
                    }

                    // stop scanning
                    // BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                    // if (scanner != null && mIsScanning) {
                    // scanner.stopScan(getScanCallback());
                    // mIsScanning = false;
                    // }

                    disconnectAllDevices("flutterHotRestart");

                    log(LogLevel.DEBUG, "connectedPeripherals: " + mConnectedDevices.size());

                    result.success(mConnectedDevices.size());
                    break;
                }

                case "setLogLevel": {
                    int idx = (int) call.arguments;

                    // set global var
                    logLevel = LogLevel.values()[idx];

                    result.success(true);
                    break;
                }

                case "isSupported": {
                    result.success(mBluetoothAdapter != null);
                    break;
                }

                case "getAdapterName": {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        String adapterName = mBluetoothAdapter != null ? mBluetoothAdapter.getName() : "N/A";
                        result.success(adapterName != null ? adapterName : "");

                    });
                    break;
                }

                case "getAdapterState": {
                    // get adapterState, if we have permission
                    int adapterState = -1; // unknown
                    try {
                        adapterState = mBluetoothAdapter.getState();
                    } catch (Exception e) {
                    }

                    // see: BmBluetoothAdapterState
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("adapter_state", bmAdapterStateEnum(adapterState));

                    result.success(map);
                    break;
                }

                case "turnOn": {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("turnOn",
                                    String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        if (mBluetoothAdapter.isEnabled()) {
                            result.success(false); // no work to do
                            return;
                        }

                        Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);

                        activityBinding.getActivity().startActivityForResult(enableBtIntent,
                                enableBluetoothRequestCode);

                        result.success(true);
                        return;
                    });
                    break;
                }

                case "turnOff": {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (!granted) {
                            result.error("turnOff",
                                    String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        if (!mBluetoothAdapter.isEnabled()) {
                            result.success(false); // no work to do
                            return;
                        }

                        // this is deprecated in API level 33.
                        boolean disabled = mBluetoothAdapter.disable();

                        result.success(disabled);
                        return;
                    });
                    break;
                }

                case "connect": {
                    // see: BmConnectRequest
                    HashMap<String, Object> args = call.arguments();
                    String remoteId = (String) args.get("remote_id");
                    boolean autoConnect = ((int) args.get("auto_connect")) != 0;

                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("connect",
                                    String.format("FlutterBluePlus requires %s for new connection", perm), null);
                            return;
                        }

                        // check adapter
                        if (isAdapterOn() == false) {
                            result.error("connect", String.format("bluetooth must be turned on"), null);
                            return;
                        }

                        // already connected?
                        if (mConnectedDevices.get(remoteId) != null) {
                            log(LogLevel.DEBUG, "already connected");
                            result.success(false); // no work to do
                            return;
                        }

                        // wait if any device is bonding (increases reliability)
                        waitIfBonding();

                        // connect
                        // BluetoothGatt gatt = null;
                        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                        // add to currently connecting peripherals

                        if (mBluetoothSocket == null) {
                            try {
                                log(LogLevel.DEBUG, "--> createRfcommSocketToServiceRecord");
                                mBluetoothSocket = device.createRfcommSocketToServiceRecord(PRINTER_UUID);
                                mBluetoothSocket.connect();
                            } catch (IOException e) {
                                log(LogLevel.DEBUG, "--> createInsecureRfcommSocketToServiceRecord");
                                try {
                                    mBluetoothSocket = device.createInsecureRfcommSocketToServiceRecord(PRINTER_UUID);
                                    mBluetoothSocket.connect();
                                } catch (IOException ex) {
                                    throw new RuntimeException(ex);
                                }
                            }

                        }

                        if (mBluetoothSocket != null) {
                            mConnectedDevices.put(remoteId, device);
                        }

                        // see: BmConnectionStateResponse
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("remote_id", remoteId);
                        response.put("connection_state", bmConnectionStateEnum(BluetoothProfile.STATE_CONNECTED));
                        // response.put("disconnect_reason_code", 23789258); // random value
                        // response.put("disconnect_reason_string", "connection canceled");

                        invokeMethodUIThread("OnConnectionStateChanged", response);

                        result.success(true);
                    });
                    break;
                }

                case "disconnect": {
                    String remoteId = (String) call.arguments;

                    // already disconnected?
                    if (mBluetoothSocket == null) {
                        log(LogLevel.DEBUG, "already disconnected");
                        result.success(false); // no work to do
                        return;
                    }

                    // disconnect
                    try {
                        OutputStream out = mBluetoothSocket.getOutputStream();
                        out.close();
                        mBluetoothSocket.close();
                        mBluetoothSocket = null;
                    } catch (IOException e) {
                        e.printStackTrace();
                    }

                    // see: BmConnectionStateResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("remote_id", remoteId);
                    response.put("connection_state", bmConnectionStateEnum(BluetoothProfile.STATE_DISCONNECTED));
                    response.put("disconnect_reason_code", 23789258); // random value
                    response.put("disconnect_reason_string", "connection canceled");

                    invokeMethodUIThread("OnConnectionStateChanged", response);

                    result.success(true);
                    break;
                }

                case "getBondedDevices": {
                    final Set<BluetoothDevice> bondedDevices = mBluetoothAdapter.getBondedDevices();

                    List<HashMap<String, Object>> devList = new ArrayList<HashMap<String, Object>>();
                    for (BluetoothDevice d : bondedDevices) {
                        devList.add(bmBluetoothDevice(d));
                    }

                    HashMap<String, Object> response = new HashMap<String, Object>();
                    response.put("devices", devList);

                    result.success(response);
                    break;
                }

                // ██████╗░██████╗░██╗███╗░░██╗████████╗███████╗██████╗░
                // ██╔══██╗██╔══██╗██║████╗░██║╚══██╔══╝██╔════╝██╔══██╗
                // ██████╔╝██████╔╝██║██╔██╗██║░░░██║░░░█████╗░░██████╔╝
                // ██╔═══╝░██╔══██╗██║██║╚████║░░░██║░░░██╔══╝░░██╔══██╗
                // ██║░░░░░██║░░██║██║██║░╚███║░░░██║░░░███████╗██║░░██║
                // ╚═╝░░░░░╚═╝░░╚═╝╚═╝╚═╝░░╚══╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝
                //
                // ░█████╗░░█████╗░███╗░░░███╗███╗░░░███╗░█████╗░███╗░░██╗██████╗░░██████╗
                // ██╔══██╗██╔══██╗████╗░████║████╗░████║██╔══██╗████╗░██║██╔══██╗██╔════╝
                // ██║░░╚═╝██║░░██║██╔████╔██║██╔████╔██║███████║██╔██╗██║██║░░██║╚█████╗░
                // ██║░░██╗██║░░██║██║╚██╔╝██║██║╚██╔╝██║██╔══██║██║╚████║██║░░██║░╚═══██╗
                // ╚█████╔╝╚█████╔╝██║░╚═╝░██║██║░╚═╝░██║██║░░██║██║░╚███║██████╔╝██████╔╝
                // ░╚════╝░░╚════╝░╚═╝░░░░░╚═╝╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░╚═════╝░

                /**
                 * call init printer for checking transaction
                 */
                case "initPrinter": {

                    log(LogLevel.INFO, "--> got initPrinter command");

                    final boolean success = sendDataToPrinter(ESCUtil.init_printer());

                    result.success(success);
                    break;
                }

                case "setPrinterDarkness": {

                    log(LogLevel.INFO, "--> got setPrinterDarkness command");

                    int value = (int) call.arguments;
                    final boolean success = sendDataToPrinter(ESCUtil.setPrinterDarkness(value));

                    result.success(success);
                    break;
                }

                /*
                 * String code,
                 * int modulesize,
                 * int errorlevel
                 */
                case "getPrintQRCode": {

                    log(LogLevel.INFO, "--> got getPrintQRCode command");

                    HashMap<String, Object> args = call.arguments();
                    if (args != null) {
                        String code = (String) args.get("code");

                        int modulesize = 8;
                        int errorlevel = 30;

                        if (args.get("modulesize") != null) {
                            modulesize = (int) args.get("modulesize");
                        }

                        if (args.get("errorlevel") != null) {
                            errorlevel = (int) args.get("errorlevel");
                        }

                        final boolean success = sendDataToPrinter(ESCUtil.getPrintQRCode(code, modulesize, errorlevel));

                        result.success(success);
                    }

                    result.success(false);
                    break;
                }

                /**
                 * Two horizontal two-dimensional codes custom instructions
                 * * @param code1: QR code data
                 * * @param code2: QR code data
                 * * @param modulesize: QR code block size (unit: point, value 1 to 16)
                 * * @param errorlevel: QR code error correction level (0 to 3)
                 * * 0 - Error correction level L (7%)
                 * * 1 - Error correction level M (15%)
                 * * 2 - Error correction level Q (25%)
                 * * 3 - Error correction level H (30%)
                 */
                case "getPrintDoubleQRCode": {

                    log(LogLevel.INFO, "--> got getPrintDoubleQRCode command");

                    HashMap<String, Object> args = call.arguments();
                    if (args != null) {
                        String code1 = (String) args.get("code1");
                        String code2 = (String) args.get("code2");

                        int modulesize = 8;
                        int errorlevel = 30;

                        if (args.get("modulesize") != null) {
                            modulesize = (int) args.get("modulesize");
                        }

                        if (args.get("errorlevel") != null) {
                            errorlevel = (int) args.get("errorlevel");
                        }

                        final boolean success = sendDataToPrinter(
                                ESCUtil.getPrintDoubleQRCode(code1, code2, modulesize, errorlevel));

                        result.success(success);
                    }

                    result.success(false);
                    break;
                }

                case "getPrintZXingQRCode": {

                    log(LogLevel.INFO, "--> got getPrintZXingQRCode command");

                    HashMap<String, Object> args = call.arguments();
                    if (args != null) {
                        String code = (String) args.get("code");

                        int size = 8;

                        if (args.get("size") != null) {
                            size = (int) args.get("size");
                        }

                        final boolean success = sendDataToPrinter(
                                ESCUtil.getPrintZXingQRCode(code, size));

                        result.success(success);
                    }

                    result.success(false);
                    break;
                }

                /**
                 * String data,
                 * encode "UPC-A", "UPC-E", "EAN13", "EAN8", "CODE39", "ITF", "CODABAR",
                 * "CODE93", "CODE128A", "CODE128B", "CODE128C"
                 * int symbology
                 * int height
                 * int width
                 * HRI position: int textposition: 0 null, 1 above barcode, 2 underneath, 3
                 * above & underneath
                 */
                case "getPrintBarCode": {

                    log(LogLevel.INFO, "--> got getPrintBarCode command");

                    HashMap<String, Object> args = call.arguments();
                    if (args != null) {

                        int size = 8;
                        int symbology = 0;
                        int encode = 2;
                        int height = 80;
                        int width = 2;
                        int position = 0;

                        String code = (String) args.get("code");
                        encode = (int) args.get("encode");
                        height = (int) args.get("height");
                        width = (int) args.get("width");
                        position = (int) args.get("textposition");

                        // int symbology;
                        // if(encode > 7){
                        // symbology = 8;
                        // }else{
                        // symbology = encode;
                        // }
                        // Bitmap bitmap = BitmapUtil.generateQRBitmap(code, symbology, 700, 400);

                        final boolean success = sendDataToPrinter(
                                ESCUtil.getPrintBarCode(code, encode, height, width, position));

                        result.success(success);
                    }

                    result.success(false);
                    break;
                }

                case "sendData": {

                    byte[] data = (byte[]) call.arguments;
                    log(LogLevel.INFO, "--> got send data command | length = " + data.length);

                    final boolean success = sendDataToPrinter(data);

                    result.success(success);
                    break;
                }

                case "printText": {

                    HashMap<String, Object> args = call.arguments();

                    String data = (String) args.get("text");
                    // utf-8 - gb-1258...
                    String charset = (String) args.get("charset");

                    log(LogLevel.INFO, "--> got print text command | text = " + data);

                    final boolean success = sendDataToPrinter(data.getBytes(StandardCharsets.UTF_8));

                    result.success(success);
                    break;
                }

                /**
                 * DO NOT USE THIS
                 */
                case "printBitmap": {

                    byte[] data = (byte[]) call.arguments;
                    log(LogLevel.INFO, "--> got printBitmap command | length = " + data.length);

                    final Bitmap temp = BitmapFactory.decodeByteArray(data, 0, data.length);

                    // final Bitmap bitmap = BitmapUtil.resizeImage(temp, PRINT_WIDTH_65, false);

                    final boolean success = sendDataToPrinter(ESCUtil.printBitmap(temp));

                    result.success(success);
                    break;
                }

                case "printBitmapMode": {

                    int width = (int) call.arguments;
                    log(LogLevel.INFO, "--> got set printBitmapMode command | width = " + width);

                    final boolean success = sendDataToPrinter(ESCUtil.printBitmapMode(width));

                    result.success(success);
                    break;
                }

                case "printByteBitmap": {

                    byte[] data = (byte[]) call.arguments;
                    log(LogLevel.INFO, "--> got printByteBitmap command | length = " + data.length);

                    final boolean success = sendDataToPrinter(ESCUtil.printBitmap(data));

                    result.success(success);
                    break;
                }

                case "printRasterBitmap": {

                    HashMap<String, Object> args = call.arguments();

                    byte[] data = (byte[]) args.get("data");
                    int mode = (int) args.get("mode");

                    log(LogLevel.INFO, "--> got printRasterBitmap command | length = " + data.length);

                    final Bitmap temp = BitmapFactory.decodeByteArray(data, 0, data.length);

                    final Bitmap bitmap = BitmapUtil.resizeImage(temp, PRINT_WIDTH_65, false);

                    final boolean success = sendDataToPrinter(ESCUtil.printRasterBitmap(bitmap, mode));

                    result.success(success);
                    break;
                }

                case "printNextLine": {
                    int data = (int) call.arguments;
                    log(LogLevel.INFO, "--> got next line command = " + data);

                    final boolean success = sendDataToPrinter(ESCUtil.nextLine(data));

                    result.success(success);
                    break;
                }

                case "partialCut": {
                    log(LogLevel.INFO, "--> got partial cut command ");

                    final boolean success = sendDataToPrinter(ESCUtil.partialCut());

                    result.success(success);
                    break;
                }
                case "fullCut": {
                    log(LogLevel.INFO, "--> got full cut command");

                    final boolean success = sendDataToPrinter(ESCUtil.fullCut());

                    result.success(success);
                    break;
                }

                case "setDefaultLineSpace": {
                    log(LogLevel.INFO, "--> got setDefaultLineSpace command");

                    final boolean success = sendDataToPrinter(ESCUtil.setDefaultLineSpace());

                    result.success(success);
                    break;
                }

                case "setLineSpace": {
                    log(LogLevel.INFO, "--> got setLineSpace command");
                    int height = (int) call.arguments;
                    final boolean success = sendDataToPrinter(ESCUtil.setLineSpace(height));
                    result.success(success);
                    break;
                }

                case "underlineWithOneDotWidthOn": {
                    log(LogLevel.INFO, "--> got underlineWithOneDotWidthOn command");
                    final boolean success = sendDataToPrinter(ESCUtil.underlineWithOneDotWidthOn());
                    result.success(success);
                    break;
                }

                case "underlineWithTwoDotWidthOn": {
                    log(LogLevel.INFO, "--> got underlineWithTwoDotWidthOn command");
                    final boolean success = sendDataToPrinter(ESCUtil.underlineWithTwoDotWidthOn());
                    result.success(success);
                    break;
                }

                case "underlineOff": {
                    log(LogLevel.INFO, "--> got underlineOff command");
                    final boolean success = sendDataToPrinter(ESCUtil.underlineOff());
                    result.success(success);
                    break;
                }

                case "boldOn": {
                    log(LogLevel.INFO, "--> got boldOn command");
                    final boolean success = sendDataToPrinter(ESCUtil.boldOn());
                    result.success(success);
                    break;
                }

                case "b68boldOn": {
                    log(LogLevel.INFO, "--> got b68boldOn command");
                    final boolean success = sendDataToPrinter(ESCUtil.boldOn());
                    result.success(success);
                    break;
                }

                case "boldOff": {
                    log(LogLevel.INFO, "--> got boldOff command");
                    final boolean success = sendDataToPrinter(ESCUtil.boldOn());
                    result.success(success);
                    break;
                }

                case "alignLeft": {
                    log(LogLevel.INFO, "--> got align left command");
                    final boolean success = sendDataToPrinter(ESCUtil.alignLeft());
                    result.success(success);
                    break;
                }

                case "alignRight": {
                    log(LogLevel.INFO, "--> got align right command");
                    final boolean success = sendDataToPrinter(ESCUtil.alignRight());
                    result.success(success);
                    break;
                }

                case "alignCenter": {
                    log(LogLevel.INFO, "--> got align center command");
                    final boolean success = sendDataToPrinter(ESCUtil.alignCenter());
                    result.success(success);
                    break;
                }

                case "singleByte": {
                    log(LogLevel.INFO, "--> got single byte command");
                    final boolean success = sendDataToPrinter(ESCUtil.singleByte());
                    result.success(success);
                    break;
                }

                case "singleByteOff": {
                    log(LogLevel.INFO, "--> got single byte off command");
                    final boolean success = sendDataToPrinter(ESCUtil.singleByteOff());
                    result.success(success);
                    break;
                }

                case "setCodeSystem": {
                    log(LogLevel.INFO, "--> got setCodeSystem command");
                    byte charset = (byte) call.arguments;
                    final boolean success = sendDataToPrinter(ESCUtil.setCodeSystem(charset));
                    result.success(success);
                    break;
                }

                case "setCodeSystemSingle": {
                    log(LogLevel.INFO, "--> got setCodeSystemSingle command");
                    byte charset = (byte) call.arguments;
                    final boolean success = sendDataToPrinter(ESCUtil.setCodeSystemSingle(charset));
                    result.success(success);
                    break;
                }

                default: {
                    result.notImplemented();
                    break;
                }
            }
        } catch (Exception e) {
            StringWriter sw = new StringWriter();
            PrintWriter pw = new PrintWriter(sw);
            e.printStackTrace(pw);
            String stackTrace = sw.toString();
            result.error("androidException", e.toString(), stackTrace);
            return;
        }
    }

    /**
     * sendData
     *
     *
     * send esc cmd
     */
    private boolean sendDataToPrinter(byte[] bytes) {

        log(LogLevel.INFO, "--> sendData " + Arrays.toString(bytes));

        // log(LogLevel.INFO, "--> sendData convert to String = " + new String(bytes,
        // StandardCharsets.UTF_8));

        if (mBluetoothSocket != null) {
            Thread thread = new Thread(() -> {
                try {
                    OutputStream out = mBluetoothSocket.getOutputStream();
                    out.write(bytes, 0, bytes.length);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });

            thread.start();

            return true;
        
        } else {
            log(LogLevel.ERROR, "--> BLE socket NULL <--");
            return false;
        }
    }

    // See: BmBluetoothDevice
    @SuppressLint("MissingPermission")
    HashMap<String, Object> bmBluetoothDevice(BluetoothDevice device) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("platform_name", device.getName());
        return map;
    }

    //////////////////////////////////////////////////////////////////////
    // █████ ██████ ████████ ██ ██ ██ ██ ████████ ██ ██
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ███████ ██ ██ ██ ██ ██ ██ ██ ████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ██████ ██ ██ ████ ██ ██ ██
    //
    // ██████ ███████ ███████ ██ ██ ██ ████████
    // ██ ██ ██ ██ ██ ██ ██ ██
    // ██████ █████ ███████ ██ ██ ██ ██
    // ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ███████ ███████ ██████ ███████ ██

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == enableBluetoothRequestCode) {

            // see: BmTurnOnResponse
            HashMap<String, Object> map = new HashMap<>();
            map.put("user_accepted", resultCode == Activity.RESULT_OK);

            invokeMethodUIThread("OnTurnOnResponse", map);

            return true;
        }

        return false; // did not handle anything
    }

    //////////////////////////////////////////////////////////////////////////////////////
    // ██████ ███████ ██████ ███ ███ ██ ███████ ███████ ██ ██████ ███ ██
    // ██ ██ ██ ██ ██ ████ ████ ██ ██ ██ ██ ██ ██ ████ ██
    // ██████ █████ ██████ ██ ████ ██ ██ ███████ ███████ ██ ██ ██ ██ ██ ██
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ███████ ██ ██ ██ ██ ██ ███████ ███████ ██ ██████ ██ ████

    @Override
    public boolean onRequestPermissionsResult(int requestCode,
            String[] permissions,
            int[] grantResults) {
        OperationOnPermission operation = operationsOnPermission.get(requestCode);

        if (operation != null && grantResults.length > 0) {
            operation.op(grantResults[0] == PackageManager.PERMISSION_GRANTED, permissions[0]);
            return true;
        } else {
            return false;
        }
    }

    private void ensurePermissions(List<String> permissions, OperationOnPermission operation) {
        // only request permission we don't already have
        List<String> permissionsNeeded = new ArrayList<>();
        for (String permission : permissions) {
            if (permission != null
                    && ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(permission);
            }
        }

        // no work to do?
        if (permissionsNeeded.isEmpty()) {
            operation.op(true, null);
            return;
        }

        askPermission(permissionsNeeded, operation);
    }

    private void askPermission(List<String> permissionsNeeded, OperationOnPermission operation) {
        // finished asking for permission? call callback
        if (permissionsNeeded.isEmpty()) {
            operation.op(true, null);
            return;
        }

        String nextPermission = permissionsNeeded.remove(0);

        operationsOnPermission.put(lastEventId, (granted, perm) -> {
            operationsOnPermission.remove(lastEventId);
            if (!granted) {
                operation.op(false, perm);
                return;
            }
            // recursively ask for next permission
            askPermission(permissionsNeeded, operation);
        });

        ActivityCompat.requestPermissions(
                activityBinding.getActivity(),
                new String[] { nextPermission },
                lastEventId);

        lastEventId++;
    }

    //////////////////////////////////////////////
    // ██████ ██ ███████
    // ██ ██ ██ ██
    // ██████ ██ █████
    // ██ ██ ██ ██
    // ██████ ███████ ███████
    //
    // ██ ██ ████████ ██ ██ ███████
    // ██ ██ ██ ██ ██ ██
    // ██ ██ ██ ██ ██ ███████
    // ██ ██ ██ ██ ██ ██
    // ██████ ██ ██ ███████ ███████

    private void waitIfBonding() {
        int counter = 0;
        if (mBondingDevices.isEmpty() == false) {
            if (counter == 0) {
                log(LogLevel.DEBUG, "[FBP] waiting for bonding to complete...");
            }
            try {
                Thread.sleep(50);
            } catch (Exception e) {
            }
            counter++;
        }
        if (counter > 0) {
            log(LogLevel.DEBUG, "[FBP] bonding completed");
        }
    }

    private void disconnectAllDevices(String func) {
        log(LogLevel.DEBUG, "disconnectAllDevices(" + func + ")");

        // request disconnections
        // TODO:
        // Jimmy - BluetoothSocker > close

        if (mBluetoothSocket != null) {
            try {
                OutputStream out = mBluetoothSocket.getOutputStream();
                out.close();
                mBluetoothSocket.close();
                mBluetoothSocket = null;
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        mConnectedDevices.clear();

        mBondingDevices.clear();
    }

    /////////////////////////////////////////////////////////////////////////////////////
    // █████ ██████ █████ ██████ ████████ ███████ ██████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ███████ ██ ██ ███████ ██████ ██ █████ ██████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ██████ ██ ██ ██ ██ ███████ ██ ██
    //
    // ██████ ███████ ██████ ███████ ██ ██ ██ ███████ ██████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██████ █████ ██ █████ ██ ██ ██ █████ ██████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ███████ ██████ ███████ ██ ████ ███████ ██ ██

    private final BroadcastReceiver mBluetoothAdapterStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();

            // no change?
            if (action == null || BluetoothAdapter.ACTION_STATE_CHANGED.equals(action) == false) {
                return;
            }

            final int adapterState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);

            log(LogLevel.DEBUG, "OnAdapterStateChanged: " + adapterStateString(adapterState));

            // disconnect all devices
            if (adapterState == BluetoothAdapter.STATE_TURNING_OFF ||
                    adapterState == BluetoothAdapter.STATE_OFF) {
                disconnectAllDevices("adapterTurnOff");
            }

            // see: BmBluetoothAdapterState
            HashMap<String, Object> map = new HashMap<>();
            map.put("adapter_state", bmAdapterStateEnum(adapterState));

            invokeMethodUIThread("OnAdapterStateChanged", map);
        }
    };

    /////////////////////////////////////////////////////////////////////////////////////
    // ██████ ██████ ███ ██ ██████
    // ██ ██ ██ ██ ████ ██ ██ ██
    // ██████ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██████ ██████ ██ ████ ██████
    //
    // ██████ ███████ ██████ ███████ ██ ██ ██ ███████ ██████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██████ █████ ██ █████ ██ ██ ██ █████ ██████
    // ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
    // ██ ██ ███████ ██████ ███████ ██ ████ ███████ ██ ██

    private final BroadcastReceiver mBluetoothBondStateReceiver = new BroadcastReceiver() {
        @Override
        @SuppressWarnings("deprecation") // need for compatability
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();

            // no change?
            if (action == null || action.equals(BluetoothDevice.ACTION_BOND_STATE_CHANGED) == false) {
                return;
            }

            // BluetoothDevice
            final BluetoothDevice device;
            if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)
                device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice.class);
            } else {
                device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
            }

            final int cur = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR);
            final int prev = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, -1);

            log(LogLevel.DEBUG, "OnBondStateChanged: " + bondStateString(cur) + " prev: " + bondStateString(prev));

            String remoteId = device.getAddress();

            // remember which devices are currently bonding
            if (cur == BluetoothDevice.BOND_BONDING) {
                mBondingDevices.put(remoteId, device);
            } else {
                mBondingDevices.remove(remoteId);
            }

            // see: BmBondStateResponse
            HashMap<String, Object> map = new HashMap<>();
            map.put("remote_id", remoteId);
            map.put("bond_state", bmBondStateEnum(cur));
            map.put("prev_state", bmBondStateEnum(prev));

            invokeMethodUIThread("OnBondStateChanged", map);
        }
    };

    // See: BmConnectionStateEnum
    static int bmConnectionStateEnum(int cs) {
        switch (cs) {
            case BluetoothProfile.STATE_DISCONNECTED:
                return 0;
            case BluetoothProfile.STATE_CONNECTED:
                return 1;
            default:
                return 0;
        }
    }

    // See: BmAdapterStateEnum
    static int bmAdapterStateEnum(int as) {
        switch (as) {
            case BluetoothAdapter.STATE_OFF:
                return 6;
            case BluetoothAdapter.STATE_ON:
                return 4;
            case BluetoothAdapter.STATE_TURNING_OFF:
                return 5;
            case BluetoothAdapter.STATE_TURNING_ON:
                return 3;
            default:
                return 0;
        }
    }

    // See: BmBondStateEnum
    static int bmBondStateEnum(int bs) {
        switch (bs) {
            case BluetoothDevice.BOND_NONE:
                return 0;
            case BluetoothDevice.BOND_BONDING:
                return 1;
            case BluetoothDevice.BOND_BONDED:
                return 2;
            default:
                return 0;
        }
    }

    // See: BmConnectionPriority
    static int bmConnectionPriorityParse(int value) {
        switch (value) {
            case 0:
                return BluetoothGatt.CONNECTION_PRIORITY_BALANCED;
            case 1:
                return BluetoothGatt.CONNECTION_PRIORITY_HIGH;
            case 2:
                return BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER;
            default:
                return BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER;
        }
    }

    //////////////////////////////////////////
    // ██ ██ ████████ ██ ██ ███████
    // ██ ██ ██ ██ ██ ██
    // ██ ██ ██ ██ ██ ███████
    // ██ ██ ██ ██ ██ ██
    // ██████ ██ ██ ███████ ███████

    private void log(LogLevel level, String message) {
        // if (level.ordinal() > logLevel.ordinal()) {
        // return;
        // }
        switch (level) {
            case DEBUG:
                Log.d(TAG, "[FBP] " + message);
                break;
            case WARNING:
                Log.w(TAG, "[FBP] " + message);
                break;
            case ERROR:
                Log.e(TAG, "[FBP] " + message);
                break;
            default:
                Log.d(TAG, "[FBP] " + message);
                break;
        }
    }

    private void invokeMethodUIThread(final String method, HashMap<String, Object> data) {
        new Handler(Looper.getMainLooper()).post(() -> {
            // Could already be teared down at this moment
            if (methodChannel != null) {
                methodChannel.invokeMethod(method, data);
            } else {
                log(LogLevel.WARNING, "invokeMethodUIThread: tried to call method on closed channel: " + method);
            }
        });
    }

    private boolean isAdapterOn() {
        // get adapterState, if we have permission
        try {
            return mBluetoothAdapter.getState() == BluetoothAdapter.STATE_ON;
        } catch (Exception e) {
            return false;
        }
    }

    private static String connectionStateString(int cs) {
        switch (cs) {
            case BluetoothProfile.STATE_DISCONNECTED:
                return "disconnected";
            case BluetoothProfile.STATE_CONNECTING:
                return "connecting";
            case BluetoothProfile.STATE_CONNECTED:
                return "connected";
            case BluetoothProfile.STATE_DISCONNECTING:
                return "disconnecting";
            default:
                return "UNKNOWN_CONNECTION_STATE (" + cs + ")";
        }
    }

    private static String adapterStateString(int as) {
        switch (as) {
            case BluetoothAdapter.STATE_OFF:
                return "off";
            case BluetoothAdapter.STATE_ON:
                return "on";
            case BluetoothAdapter.STATE_TURNING_OFF:
                return "turningOff";
            case BluetoothAdapter.STATE_TURNING_ON:
                return "turningOn";
            default:
                return "UNKNOWN_ADAPTER_STATE (" + as + ")";
        }
    }

    private static String bondStateString(int bs) {
        switch (bs) {
            case BluetoothDevice.BOND_BONDING:
                return "bonding";
            case BluetoothDevice.BOND_BONDED:
                return "bonded";
            case BluetoothDevice.BOND_NONE:
                return "bond-none";
            default:
                return "UNKNOWN_BOND_STATE (" + bs + ")";
        }
    }

    // Defined in the Bluetooth Standard
    private static String gattErrorString(int value) {
        switch (value) {
            case BluetoothGatt.GATT_SUCCESS:
                return "GATT_SUCCESS"; // 0
            case 0x01:
                return "GATT_INVALID_HANDLE"; // 1
            case BluetoothGatt.GATT_READ_NOT_PERMITTED:
                return "GATT_READ_NOT_PERMITTED"; // 2
            case BluetoothGatt.GATT_WRITE_NOT_PERMITTED:
                return "GATT_WRITE_NOT_PERMITTED"; // 3
            case 0x04:
                return "GATT_INVALID_PDU"; // 4
            case BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION:
                return "GATT_INSUFFICIENT_AUTHENTICATION"; // 5
            case BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED:
                return "GATT_REQUEST_NOT_SUPPORTED"; // 6
            case BluetoothGatt.GATT_INVALID_OFFSET:
                return "GATT_INVALID_OFFSET"; // 7
            case BluetoothGatt.GATT_INSUFFICIENT_AUTHORIZATION:
                return "GATT_INSUFFICIENT_AUTHORIZATION"; // 8
            case 0x09:
                return "GATT_PREPARE_QUEUE_FULL"; // 9
            case 0x0a:
                return "GATT_ATTR_NOT_FOUND"; // 10
            case 0x0b:
                return "GATT_ATTR_NOT_LONG"; // 11
            case 0x0c:
                return "GATT_INSUFFICIENT_KEY_SIZE"; // 12
            case BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH:
                return "GATT_INVALID_ATTRIBUTE_LENGTH"; // 13
            case 0x0e:
                return "GATT_UNLIKELY"; // 14
            case BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION:
                return "GATT_INSUFFICIENT_ENCRYPTION"; // 15
            case 0x10:
                return "GATT_UNSUPPORTED_GROUP"; // 16
            case 0x11:
                return "GATT_INSUFFICIENT_RESOURCES"; // 17
            case BluetoothGatt.GATT_CONNECTION_CONGESTED:
                return "GATT_CONNECTION_CONGESTED"; // 143
            case BluetoothGatt.GATT_FAILURE:
                return "GATT_FAILURE"; // 257
            default:
                return "UNKNOWN_GATT_ERROR (" + value + ")";
        }
    }

    private static String bluetoothStatusString(int value) {
        switch (value) {
            case BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ALLOWED:
                return "ERROR_BLUETOOTH_NOT_ALLOWED";
            case BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ENABLED:
                return "ERROR_BLUETOOTH_NOT_ENABLED";
            case BluetoothStatusCodes.ERROR_DEVICE_NOT_BONDED:
                return "ERROR_DEVICE_NOT_BONDED";
            case BluetoothStatusCodes.ERROR_GATT_WRITE_NOT_ALLOWED:
                return "ERROR_GATT_WRITE_NOT_ALLOWED";
            case BluetoothStatusCodes.ERROR_GATT_WRITE_REQUEST_BUSY:
                return "ERROR_GATT_WRITE_REQUEST_BUSY";
            case BluetoothStatusCodes.ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION:
                return "ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION";
            case BluetoothStatusCodes.ERROR_PROFILE_SERVICE_NOT_BOUND:
                return "ERROR_PROFILE_SERVICE_NOT_BOUND";
            case BluetoothStatusCodes.ERROR_UNKNOWN:
                return "ERROR_UNKNOWN";
            // case BluetoothStatusCodes.FEATURE_NOT_CONFIGURED : return
            // "FEATURE_NOT_CONFIGURED";
            case BluetoothStatusCodes.FEATURE_NOT_SUPPORTED:
                return "FEATURE_NOT_SUPPORTED";
            case BluetoothStatusCodes.FEATURE_SUPPORTED:
                return "FEATURE_SUPPORTED";
            case BluetoothStatusCodes.SUCCESS:
                return "SUCCESS";
            default:
                return "UNKNOWN_BLE_ERROR (" + value + ")";
        }
    }

    private static String scanFailedString(int value) {
        switch (value) {
            case ScanCallback.SCAN_FAILED_ALREADY_STARTED:
                return "SCAN_FAILED_ALREADY_STARTED";
            case ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED:
                return "SCAN_FAILED_APPLICATION_REGISTRATION_FAILED";
            case ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED:
                return "SCAN_FAILED_FEATURE_UNSUPPORTED";
            case ScanCallback.SCAN_FAILED_INTERNAL_ERROR:
                return "SCAN_FAILED_INTERNAL_ERROR";
            case ScanCallback.SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES:
                return "SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES";
            case ScanCallback.SCAN_FAILED_SCANNING_TOO_FREQUENTLY:
                return "SCAN_FAILED_SCANNING_TOO_FREQUENTLY";
            default:
                return "UNKNOWN_SCAN_ERROR (" + value + ")";
        }
    }

    // Defined in the Bluetooth Standard, Volume 1, Part F, 1.3 HCI Error Code,
    // pages 364-377.
    // See https://www.bluetooth.org/docman/handlers/downloaddoc.ashx?doc_id=478726,
    private static String hciStatusString(int value) {
        switch (value) {
            case 0x00:
                return "SUCCESS";
            case 0x01:
                return "UNKNOWN_COMMAND"; // The controller does not understand the HCI Command Packet OpCode that the
            // Host sent.
            case 0x02:
                return "UNKNOWN_CONNECTION_IDENTIFIER"; // The connection identifier used is unknown
            case 0x03:
                return "HARDWARE_FAILURE"; // A hardware failure has occurred
            case 0x04:
                return "PAGE_TIMEOUT"; // a page timed out because of the Page Timeout configuration parameter.
            case 0x05:
                return "AUTHENTICATION_FAILURE"; // Pairing or authentication failed. This could be due to an incorrect
            // PIN or Link Key.
            case 0x06:
                return "PIN_OR_KEY_MISSING"; // Pairing failed because of a missing PIN
            case 0x07:
                return "MEMORY_FULL"; // The Controller has run out of memory to store new parameters.
            case 0x08:
                return "CONNECTION_TIMEOUT"; // The link supervision timeout has expired for a given connection.
            case 0x09:
                return "CONNECTION_LIMIT_EXCEEDED"; // The Controller is already at its limit of the number of
            // connections it can support.
            case 0x0A:
                return "MAX_NUM_OF_CONNECTIONS_EXCEEDED"; // The Controller has reached the limit of connections
            case 0x0B:
                return "CONNECTION_ALREADY_EXISTS"; // A connection to this device already exists
            case 0x0C:
                return "COMMAND_DISALLOWED"; // The command requested cannot be executed by the Controller at this time.
            case 0x0D:
                return "CONNECTION_REJECTED_LIMITED_RESOURCES"; // A connection was rejected due to limited resources.
            case 0x0E:
                return "CONNECTION_REJECTED_SECURITY_REASONS"; // A connection was rejected due to security, e.g. aauth
            // or pairing.
            case 0x0F:
                return "CONNECTION_REJECTED_UNACCEPTABLE_MAC_ADDRESS"; // connection rejected, this device does not
            // accept the BD_ADDR
            case 0x10:
                return "CONNECTION_ACCEPT_TIMEOUT_EXCEEDED"; // Connection Accept Timeout exceeded for this connection
            // attempt.
            case 0x11:
                return "UNSUPPORTED_PARAMETER_VALUE"; // A feature or parameter value in the HCI command is not
            // supported.
            case 0x12:
                return "INVALID_COMMAND_PARAMETERS"; // At least one of the HCI command parameters is invalid.
            case 0x13:
                return "REMOTE_USER_TERMINATED_CONNECTION"; // The user on the remote device terminated the connection.
            case 0x14:
                return "REMOTE_DEVICE_TERMINATED_CONNECTION_LOW_RESOURCES"; // remote device terminated connection due
            // to low resources.
            case 0x15:
                return "REMOTE_DEVICE_TERMINATED_CONNECTION_POWER_OFF"; // The remote device terminated the connection
            // due to power off
            case 0x16:
                return "CONNECTION_TERMINATED_BY_LOCAL_HOST"; // The local device terminated the connection.
            case 0x17:
                return "REPEATED_ATTEMPTS"; // The Controller is disallowing auth because of too quick attempts.
            case 0x18:
                return "PAIRING_NOT_ALLOWED"; // The device does not allow pairing
            case 0x19:
                return "UNKNOWN_LMP_PDU"; // The Controller has received an unknown LMP OpCode.
            case 0x1A:
                return "UNSUPPORTED_REMOTE_FEATURE"; // The remote device does not support feature for the issued
            // command or LMP PDU.
            case 0x1B:
                return "SCO_OFFSET_REJECTED"; // The offset requested in the LMP_SCO_link_req PDU has been rejected.
            case 0x1C:
                return "SCO_INTERVAL_REJECTED"; // The interval requested in the LMP_SCO_link_req PDU has been rejected.
            case 0x1D:
                return "SCO_AIR_MODE_REJECTED"; // The air mode requested in the LMP_SCO_link_req PDU has been rejected.
            case 0x1E:
                return "INVALID_LMP_OR_LL_PARAMETERS"; // Some LMP PDU / LL Control PDU parameters were invalid.
            case 0x1F:
                return "UNSPECIFIED"; // No other error code specified is appropriate to use
            case 0x20:
                return "UNSUPPORTED_LMP_OR_LL_PARAMETER_VALUE"; // An LMP PDU or an LL Control PDU contains a value that
            // is not supported
            case 0x21:
                return "ROLE_CHANGE_NOT_ALLOWED"; // a Controller will not allow a role change at this time.
            case 0x22:
                return "LMP_OR_LL_RESPONSE_TIMEOUT"; // An LMP transaction failed to respond within the LMP response
            // timeout
            case 0x23:
                return "LMP_OR_LL_ERROR_TRANS_COLLISION"; // An LMP transaction or LL procedure has collided with the
            // same transaction
            case 0x24:
                return "LMP_PDU_NOT_ALLOWED"; // A Controller sent an LMP PDU with an OpCode that was not allowed.
            case 0x25:
                return "ENCRYPTION_MODE_NOT_ACCEPTABLE"; // The requested encryption mode is not acceptable at this
            // time.
            case 0x26:
                return "LINK_KEY_CANNOT_BE_EXCHANGED"; // A link key cannot be changed because a fixed unit key is being
            // used.
            case 0x27:
                return "REQUESTED_QOS_NOT_SUPPORTED"; // The requested Quality of Service is not supported.
            case 0x28:
                return "INSTANT_PASSED"; // The LMP PDU or LL PDU instant has already passed
            case 0x29:
                return "PAIRING_WITH_UNIT_KEY_NOT_SUPPORTED"; // It was not possible to pair as a unit key is not
            // supported.
            case 0x2A:
                return "DIFFERENT_TRANSACTION_COLLISION"; // An LMP transaction or LL Procedure collides with an ongoing
            // transaction.
            case 0x2B:
                return "UNDEFINED_0x2B"; // Undefined error code
            case 0x2C:
                return "QOS_UNACCEPTABLE_PARAMETER"; // The quality of service parameters could not be accepted at this
            // time.
            case 0x2D:
                return "QOS_REJECTED"; // The specified quality of service parameters cannot be accepted. negotiation
            // should be terminated
            case 0x2E:
                return "CHANNEL_CLASSIFICATION_NOT_SUPPORTED"; // The Controller cannot perform channel assessment. not
            // supported.
            case 0x2F:
                return "INSUFFICIENT_SECURITY"; // The HCI command or LMP PDU sent is only possible on an encrypted
            // link.
            case 0x30:
                return "PARAMETER_OUT_OF_RANGE"; // A parameter in the HCI command is outside of valid range
            case 0x31:
                return "UNDEFINED_0x31"; // Undefined error
            case 0x32:
                return "ROLE_SWITCH_PENDING"; // A Role Switch is pending, sothe HCI command or LMP PDU is rejected
            case 0x33:
                return "UNDEFINED_0x33"; // Undefined error
            case 0x34:
                return "RESERVED_SLOT_VIOLATION"; // Synchronous negotiation terminated with negotiation state set to
            // Reserved Slot Violation.
            case 0x35:
                return "ROLE_SWITCH_FAILED"; // A role switch was attempted but it failed and the original piconet
            // structure is restored.
            case 0x36:
                return "INQUIRY_RESPONSE_TOO_LARGE"; // The extended inquiry response is too large to fit in packet
            // supported by Controller.
            case 0x37:
                return "SECURE_SIMPLE_PAIRING_NOT_SUPPORTED"; // Host does not support Secure Simple Pairing, but
            // receiving Link Manager does.
            case 0x38:
                return "HOST_BUSY_PAIRING"; // The Host is busy with another pairing operation. The receiving device
            // should retry later.
            case 0x39:
                return "CONNECTION_REJECTED_NO_SUITABLE_CHANNEL"; // Controller could not calculate an appropriate value
            // for Channel selection.
            case 0x3A:
                return "CONTROLLER_BUSY"; // The Controller was busy and unable to process the request.
            case 0x3B:
                return "UNACCEPTABLE_CONNECTION_PARAMETERS"; // The remote device terminated connection, unacceptable
            // connection parameters.
            case 0x3C:
                return "ADVERTISING_TIMEOUT"; // Advertising completed. Or for directed advertising, no connection was
            // created.
            case 0x3D:
                return "CONNECTION_TERMINATED_MIC_FAILURE"; // Connection terminated because Message Integrity Check
            // failed on received packet.
            case 0x3E:
                return "CONNECTION_FAILED_ESTABLISHMENT"; // The LL initiated a connection but the connection has failed
            // to be established.
            case 0x3F:
                return "MAC_CONNECTION_FAILED"; // The MAC of the 802.11 AMP was requested to connect to a peer, but the
            // connection failed.
            case 0x40:
                return "COARSE_CLOCK_ADJUSTMENT_REJECTED"; // The master is unable to make a coarse adjustment to the
            // piconet clock.
            case 0x41:
                return "TYPE0_SUBMAP_NOT_DEFINED"; // The LMP PDU is rejected because the Type 0 submap is not currently
            // defined.
            case 0x42:
                return "UNKNOWN_ADVERTISING_IDENTIFIER"; // A command was sent from the Host but the Advertising or Sync
            // handle does not exist.
            case 0x43:
                return "LIMIT_REACHED"; // The number of operations requested has been reached and has indicated the
            // completion of the activity
            case 0x44:
                return "OPERATION_CANCELLED_BY_HOST"; // A request to the Controller issued by the Host and still
            // pending was successfully canceled.
            case 0x45:
                return "PACKET_TOO_LONG"; // An attempt was made to send or receive a packet that exceeds the maximum
            // allowed packet length.
            case 0x85:
                return "ANDROID_SPECIFIC_ERROR"; // Additional Android specific errors
            case 0x101:
                return "FAILURE_REGISTERING_CLIENT"; // max of 30 clients has been reached.
            default:
                return "UNKNOWN_HCI_ERROR (" + value + ")";
        }
    }

    enum LogLevel {
        NONE, // 0
        ERROR, // 1
        WARNING, // 2
        INFO, // 3
        DEBUG, // 4
        VERBOSE // 5
    }
}
