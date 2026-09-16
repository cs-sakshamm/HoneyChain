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
const express_1 = require("express");
const client_1 = require("@prisma/client");
const router = (0, express_1.Router)();
const prisma = new client_1.PrismaClient();
router.get('/', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId, role } = req.query;
        if (!userId)
            return res.status(400).json({ success: false, error: 'userId is required' });
        const notifications = yield prisma.notification.findMany({
            where: Object.assign(Object.assign({ userId: String(userId) }, (role ? { role: String(role) } : {})), { status: 'ACTIVE' }),
            orderBy: { createdAt: 'desc' }
        });
        res.json(notifications);
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || 'Server error' });
    }
}));
router.post('/acknowledge/:id', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { id } = req.params;
        const { userId } = req.body;
        if (!userId)
            return res.status(400).json({ success: false, error: 'userId is required' });
        const notif = yield prisma.notification.findFirst({ where: { id, userId: String(userId) } });
        if (!notif)
            return res.status(404).json({ success: false, error: 'Not found or unauthorized' });
        const updated = yield prisma.notification.update({
            where: { id },
            data: { status: 'ACKNOWLEDGED', acknowledgedAt: new Date() }
        });
        res.json({ success: true, notification: updated });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || 'Server error' });
    }
}));
router.get('/history', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId, role } = req.query;
        if (!userId)
            return res.status(400).json({ success: false, error: 'userId is required' });
        const notifications = yield prisma.notification.findMany({
            where: Object.assign({ userId: String(userId) }, (role ? { role: String(role) } : {})),
            orderBy: { createdAt: 'desc' }, take: 50
        });
        res.json(notifications);
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || 'Server error' });
    }
}));
/**
 * POST /api/notifications
 * Create a new notification (used by workflow actions to notify users)
 */
router.post('/', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId, role, type, category, title, message, severity, isUnignorable, resourceId, details } = req.body;
        if (!userId || !title || !message) {
            return res.status(400).json({ success: false, error: 'userId, title, and message are required' });
        }
        const notification = yield prisma.notification.create({
            data: {
                userId: String(userId),
                role: role || 'HARVESTER',
                type: type || 'NORMAL',
                category: category || 'SYSTEM',
                title: String(title),
                message: String(message),
                severity: severity || 'INFO',
                isUnignorable: isUnignorable === true,
                resourceId: resourceId || null,
                details: details ? (typeof details === 'string' ? details : JSON.stringify(details)) : null,
            }
        });
        // Push via WebSocket if critical
        if (notification.isUnignorable || notification.type === 'CRITICAL') {
            try {
                const wsService = require('../services/websocketService').getWebSocketService();
                if (wsService) {
                    wsService.sendNotification(userId, { event: 'CRITICAL_ALERT', data: notification });
                }
            }
            catch (_) { }
        }
        res.status(201).json({ success: true, notification });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || 'Server error' });
    }
}));
/**
 * GET /api/notifications/critical
 * Fetch unacknowledged critical / unignorable notifications for a user
 */
router.get('/critical', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId, role } = req.query;
        if (!userId)
            return res.status(400).json({ success: false, error: 'userId is required' });
        const criticals = yield prisma.notification.findMany({
            where: Object.assign(Object.assign({ userId: String(userId) }, (role ? { role: String(role) } : {})), { status: 'ACTIVE', OR: [
                    { isUnignorable: true },
                    { type: 'CRITICAL' }
                ] }),
            orderBy: { createdAt: 'desc' }
        });
        res.json({ success: true, count: criticals.length, notifications: criticals });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || 'Server error' });
    }
}));
exports.default = router;
