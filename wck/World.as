﻿package wck {		import Box2DAS.*;	import Box2DAS.Collision.*;	import Box2DAS.Collision.Shapes.*;	import Box2DAS.Common.*;	import Box2DAS.Dynamics.*;	import Box2DAS.Dynamics.Contacts.*;	import Box2DAS.Dynamics.Joints.*;	import cmodule.Box2D.*;	import wck.*;	import gravity.*;	import misc.*;	import flash.utils.*;	import flash.events.*;	import flash.display.*;	import flash.text.*;	import flash.geom.*;	import flash.ui.*;		/**	 * Wraps b2World and provides inspectable properties that can be edited in Flash.	 */	public class World extends Scroller {				/// See the Box2d documentation for explanations of the variables below.				[Inspectable(defaultValue=60)]		public var scale:Number = 60;				[Inspectable(defaultValue=0.05)]		public var timeStep:Number = 0.05;				[Inspectable(defaultValue=15)]		public var velocityIterations:int = 10;				[Inspectable(defaultValue=15)]		public var positionIterations:int = 10;				[Inspectable(defaultValue=0)]		public var gravityX:Number = 0;				[Inspectable(defaultValue=10)]		public var gravityY:Number = 10;				[Inspectable(defaultValue=true)]		public var allowSleep:Boolean = true;				[Inspectable(defaultValue=true)]		public var allowDragging:Boolean = true;				/// When true timestep isn't called / dispatched.		[Inspectable(defaultValue=false)]		public var paused:Boolean = false;				/// Orient the world so that gravity is always up?		[Inspectable(defaultValue=false)]		public var orientToGravity:Boolean = false;				/// Show debug draw data.		[Inspectable(defaultValue=false)]		public var debugDraw:Boolean = false;				public var outsideTS:Array = [];		public var baseGravity:V2;		public var b2world:b2World;		public var customGravity:Gravity;		public var debug:b2DebugDraw;		public var kDrag:Object;				[Inspectable(defaultValue="Mouse",enumeration="Mouse,Kinematic")]		public var dragMethod:String = 'Mouse';						/// The Joint-extending class to use for mouse dragging. This can be set to provide a visual, custom mouse joint.		public static var dragJointClass:Class = wck.Joint;				/// Base strength of the drag mouse joint.		public static var dragJointStrength:Number = 100;				/// Added to the strength of the mouse joint - multiplied by the mass of the body being dragged.		public static var dragJointMassFactor:Number = 200;				/**		 * Construct the b2World.		 */		public override function create():void {			baseGravity = new V2(gravityX, gravityY);			b2world = new b2World(new V2(0, 0), allowSleep, this);			listenWhileVisible(stage, Event.ENTER_FRAME, step);			listenWhileVisible(this, StepEvent.STEP, applyGravityToWorld, false, 10);			super.create();			if(debugDraw) {				debug = new b2DebugDraw(b2world, scale);				addChild(debug);			}			listenWhileVisible(this, MouseEvent.MOUSE_DOWN, handleDragStart);		}				public var dragJoint:wck.Joint;				public function handleDragStart(e:Event):void {			var b:BodyShape = Util.findAncestorOfClass(e.target as DisplayObject, BodyShape, true) as BodyShape;			if(b && b.b2body && b.allowDragging) {				if(dragMethod == 'Mouse' && b.b2body.IsDynamic()) {					createDragJoint(b);				}				else if(dragMethod == 'Kinematic') {					b.listenWhileVisible(stage, Event.ENTER_FRAME, handleDragStep, false, 1000);					b.listenWhileVisible(stage, Input.MOUSE_UP_OR_LOST, handleDragStop);					var mp:Point = Input.mousePositionIn(this);					var bp:Point = Util.localizePoint(this, b.body);					b = b.body;					kDrag = {						body: b,						type: b.type,						autoSleep: b.autoSleep,						offset: mp.subtract(bp)					}					b.type = 'Animated';					b.awake = true;					b.autoSleep = false;				}			}		}				public function createDragJoint(b:BodyShape):void {					b.body.awake = true;			b.listenWhileVisible(stage, Event.ENTER_FRAME, handleDragStep, false, 1000);			b.listenWhileVisible(stage, Input.MOUSE_UP_OR_LOST, handleDragStop);			dragJoint = new dragJointClass() as wck.Joint;			dragJoint.maxForce = dragJointStrength + (b.b2body.m_mass * dragJointMassFactor);			dragJoint.frequencyHz = 999999;			dragJoint.dampingRatio = 0;			dragJoint.collideConnected = true;			dragJoint.type = 'Mouse';			var p:Point = Input.mousePositionIn(this);			dragJoint.x = p.x;			dragJoint.y = p.y;			dragJoint.bodyShape1 = b.body;			addChild(dragJoint);		}				/**		 * Move the target of the mouse joint.		 */		public function handleDragStep(e:Event):void {			if(dragJoint) {				(dragJoint.b2joint as b2MouseJoint).SetTarget(V2.fromP(Input.mousePositionIn(this)).divideN(scale));			}			else {				kDrag.body.setPos(Input.mousePositionIn(this).subtract(kDrag.offset));			}		}				/**		 * Destroy the mouse joint.		 */		public function handleDragStop(e:Event):void {			if(stage) {				stopListening(stage, Event.ENTER_FRAME, handleDragStep);				stopListening(stage, Input.MOUSE_UP_OR_LOST, handleDragStop);			}						if(dragJoint) {				dragJoint.remove();			}			else {				kDrag.body.type = kDrag.type;				kDrag.body.autoSleep = kDrag.autoSleep;				kDrag = null;			}		}				/**		 * Destroy the b2World.		 */		public override function destroy():void {			doOutsideTimeStep(function():void {				b2world.destroy();				b2world = null;			});		}				/**		 * Do the timestep!		 */		public function step(e:Event = null):void {			if(paused) {				return;			}			b2world.Step(timeStep, velocityIterations, positionIterations);			for(var i:uint = 0; i < outsideTS.length; ++i) {				outsideTS[i][0].apply(null, outsideTS[i][1]);			}			outsideTS = [];			if(debug) {				debug.Draw();				addChild(debug); /// Keeps the debug drawer on top.			}		}				/**		 * Loop through the body list and apply gravity. This replaces Box2d's built in gravity, which		 * is fed a zero gravity vector. 		 */		public function applyGravityToWorld(e:Event):void {			if(paused) {				return;			}			var b2:BodyShape;			for(var b:b2Body = b2world.m_bodyList; b; b = b.GetNext()) { 				b2 = b.m_userData as BodyShape;				if(b.IsAwake() && b.IsDynamic()) {					var g:V2 = getGravityFor(b.GetWorldCenter(), b, b2);					if(!b2 || b2.applyGravity) {						b.m_linearVelocity.x += timeStep * g.x;						b.m_linearVelocity.y += timeStep * g.y;					}					if(b2) {						b2.gravity = g;					}				}			}		}				/**		 * Get gravity at a specific point, for a specific body and bodyshape (if a bodyshape exists for the body). The 		 * body and bodyshape are passed so that this function can be overriden to provide different gravity for		 * different objects! This can also be overriden to implement circular gravity, capsule gravity, etc., or alter		 * each non-static non-sleeping gravity-enabled body in some other way.		 */		public function getGravityFor(p:V2, b:b2Body = null, b2:BodyShape = null):V2 {			var g:V2;			if(b2 && b2.customGravity) {				g = b2.customGravity.gravity(p, b, b2);			}			else if(customGravity) {				g = customGravity.gravity(p, b, b2);			}			else {				g = baseGravity.clone();			}			if(b2 && b2.gravityMod) {				b2.modifyGravity(g);			}			return g;		}				/**		 * Defers a function call until later if the world is currently locked. This is handy for		 * doing forbidden stuff (like destroying a body) within a contact callback, since contact callbacks		 * happen mid-timestep. If the world is not mid-timestep, the function will be called automatically.		 */		public function doOutsideTimeStep(f:Function, ...args):void {			if(b2world.IsLocked()) {				outsideTS.push([f, args]);			}			else {				f.apply(null, args);			}		}				/**		 * Override scrolling to orient based on gravity.		 */		public override function scrollRotation():Number {			if(orientToGravity) {				var b:BodyShape = focus as BodyShape;				var g:V2 = getGravityFor(V2.fromP(pos).divideN(scale), b ? b.b2body : null, b);				return (Math.atan2(g.y, -g.x) * Util.R2D) - 90;			}			return rot;		}	}}