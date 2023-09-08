package spine.animation;

import openfl.Vector;
import spine.Event;
import spine.IkConstraint;
import spine.Skeleton;

class IkConstraintTimeline extends CurveTimeline {
	private static inline var ENTRIES:Int = 6;
	private static inline var MIX:Int = 1;
	private static inline var SOFTNESS:Int = 2;
	private static inline var BEND_DIRECTION:Int = 3;
	private static inline var COMPRESS:Int = 4;
	private static inline var STRETCH:Int = 5;

	/** The index of the IK constraint slot in {@link Skeleton#ikConstraints} that will be changed. */
	public var ikConstraintIndex:Int = 0;

	public function new(frameCount:Int, bezierCount:Int, ikConstraintIndex:Int) {
		super(frameCount, bezierCount, Vector.ofArray([Property.ikConstraint + "|" + ikConstraintIndex]));
		this.ikConstraintIndex = ikConstraintIndex;
	}

	public override function getFrameEntries():Int {
		return ENTRIES;
	}

	/** Sets the time in seconds, mix, softness, bend direction, compress, and stretch for the specified key frame. */
	public function setFrame(frame:Int, time:Float, mix:Float, softness:Float, bendDirection:Int, compress:Bool, stretch:Bool):Void {
		frame *= ENTRIES;
		frames[frame] = time;
		frames[frame + MIX] = mix;
		frames[frame + SOFTNESS] = softness;
		frames[frame + BEND_DIRECTION] = bendDirection;
		frames[frame + COMPRESS] = compress ? 1 : 0;
		frames[frame + STRETCH] = stretch ? 1 : 0;
	}

	public override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Vector<Event>, alpha:Float, blend:MixBlend,
			direction:MixDirection):Void {
		var constraint:IkConstraint = skeleton.ikConstraints[ikConstraintIndex];
		if (!constraint.active)
			return;

		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					constraint.mix = constraint.data.mix;
					constraint.softness = constraint.data.softness;
					constraint.bendDirection = constraint.data.bendDirection;
					constraint.compress = constraint.data.compress;
					constraint.stretch = constraint.data.stretch;
				case MixBlend.first:
					constraint.mix += (constraint.data.mix - constraint.mix) * alpha;
					constraint.softness += (constraint.data.softness - constraint.softness) * alpha;
					constraint.bendDirection = constraint.data.bendDirection;
					constraint.compress = constraint.data.compress;
					constraint.stretch = constraint.data.stretch;
			}
			return;
		}

		var mix:Float = 0, softness:Float = 0;
		var i:Int = Timeline.search(frames, time, ENTRIES);
		var curveType:Int = Std.int(curves[Std.int(i / ENTRIES)]);
		switch (curveType) {
			case CurveTimeline.LINEAR:
				var before:Float = frames[i];
				mix = frames[i + MIX];
				softness = frames[i + SOFTNESS];
				var t:Float = (time - before) / (frames[i + ENTRIES] - before);
				mix += (frames[i + ENTRIES + MIX] - mix) * t;
				softness += (frames[i + ENTRIES + SOFTNESS] - softness) * t;
			case CurveTimeline.STEPPED:
				mix = frames[i + MIX];
				softness = frames[i + SOFTNESS];
			default:
				mix = getBezierValue(time, i, MIX, curveType - CurveTimeline.BEZIER);
				softness = getBezierValue(time, i, SOFTNESS, curveType + CurveTimeline.BEZIER_SIZE - CurveTimeline.BEZIER);
		}

		if (blend == MixBlend.setup) {
			constraint.mix = constraint.data.mix + (mix - constraint.data.mix) * alpha;
			constraint.softness = constraint.data.softness + (softness - constraint.data.softness) * alpha;
			if (direction == MixDirection.mixOut) {
				constraint.bendDirection = constraint.data.bendDirection;
				constraint.compress = constraint.data.compress;
				constraint.stretch = constraint.data.stretch;
			} else {
				constraint.bendDirection = Std.int(frames[i + BEND_DIRECTION]);
				constraint.compress = frames[i + COMPRESS] != 0;
				constraint.stretch = frames[i + STRETCH] != 0;
			}
		} else {
			constraint.mix += (mix - constraint.mix) * alpha;
			constraint.softness += (softness - constraint.softness) * alpha;
			if (direction == MixDirection.mixIn) {
				constraint.bendDirection = Std.int(frames[i + BEND_DIRECTION]);
				constraint.compress = frames[i + COMPRESS] != 0;
				constraint.stretch = frames[i + STRETCH] != 0;
			}
		}
	}
}
