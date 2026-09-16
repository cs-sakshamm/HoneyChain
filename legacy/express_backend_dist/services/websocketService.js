"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getWebSocketService = exports.initWebSocketService = exports.WebSocketService = void 0;
const ws_1 = require("ws");
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
class WebSocketService {
    constructor(server) {
        this.clients = new Set();
        this.wss = new ws_1.Server({ server, path: '/ws' });
        this.wss.on('connection', (ws, req) => {
            ws.isAlive = true;
            const url = new URL(req.url || '', `http://${req.headers.host}`);
            const userId = url.searchParams.get('userId');
            const role = url.searchParams.get('role') || 'HARVESTER';
            if (!userId) {
                ws.close(4001, 'Unauthorized: No userId provided');
                return;
            }
            ws.userId = userId;
            ws.role = role;
            this.clients.add(ws);
            ws.on('pong', () => {
                ws.isAlive = true;
            });
            ws.on('close', () => {
                this.clients.delete(ws);
            });
        });
        setInterval(() => {
            this.wss.clients.forEach((ws) => {
                if (!ws.isAlive)
                    return ws.terminate();
                ws.isAlive = false;
                ws.ping();
            });
        }, 30000);
    }
    sendNotification(userId, notification) {
        return __awaiter(this, void 0, void 0, function* () {
            const messageStr = JSON.stringify(notification);
            for (const client of this.clients) {
                if (client.userId === userId) {
                    client.send(messageStr);
                }
            }
        });
    }
    createAndSendCriticalAlert(userId, role, title, message, category, resourceId, details) {
        return __awaiter(this, void 0, void 0, function* () {
            const notif = yield prisma.notification.create({
                data: {
                    userId, role, type: 'CRITICAL', category, title, message, severity: 'CRITICAL', isUnignorable: true, resourceId, details: details ? JSON.stringify(details) : null,
                }
            });
            yield this.sendNotification(userId, { event: 'CRITICAL_ALERT', data: notif });
            return notif;
        });
    }
}
exports.WebSocketService = WebSocketService;
let wsServiceInstance = null;
const initWebSocketService = (server) => {
    wsServiceInstance = new WebSocketService(server);
    return wsServiceInstance;
};
exports.initWebSocketService = initWebSocketService;
const getWebSocketService = () => wsServiceInstance;
exports.getWebSocketService = getWebSocketService;
